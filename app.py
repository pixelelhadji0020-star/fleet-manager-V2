import os
from datetime import datetime, date
from functools import wraps
from flask import (Flask, render_template, request, redirect, url_for,
                   session, flash, jsonify, send_from_directory)
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from supabase import create_client

# ─── CONFIG ───────────────────────────────────
_root = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__,
            template_folder=os.path.join(_root, 'templates'),
            static_folder=os.path.join(_root, 'static'))
app.secret_key = os.environ.get('SECRET_KEY', 'fleet-secret-2025')

@app.template_filter('img_url')
def img_url_filter(image):
    """Retourne l'image comme src HTML.
    - data:image/...;base64,...  → retournée telle quelle
    - http/https URL             → retournée telle quelle
    - None/vide                  → chaîne vide (pas d'image cassée)
    """
    if not image:
        return ''
    if image.startswith('data:') or image.startswith('http'):
        return image
    return ''
def img_url_filter(image):
    """Normalise une valeur image en URL affichable.
    - URL complète (http/https) → retournée telle quelle
    - Nom de fichier local → '/uploads/fichier.jpg'  
    - None/vide → chaîne vide
    """
    if not image:
        return ''
    if image.startswith('http'):
        return image
    return f'/uploads/{image}'
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024
ALLOWED_EXT = {'pdf', 'png', 'jpg', 'jpeg'}

SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', '')

def sb():
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def allowed_file(f):
    return '.' in f and f.rsplit('.', 1)[1].lower() in ALLOWED_EXT

# ─── HELPERS ──────────────────────────────────
def login_required(f):
    @wraps(f)
    def dec(*a, **kw):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*a, **kw)
    return dec

def admin_required(f):
    @wraps(f)
    def dec(*a, **kw):
        if 'user_id' not in session or session.get('role') != 'admin':
            flash('Accès réservé aux administrateurs.', 'error')
            return redirect(url_for('index'))
        return f(*a, **kw)
    return dec

def get_user():
    if 'user_id' not in session:
        return None
    r = sb().table('users').select('*').eq('id', session['user_id']).single().execute()
    return r.data

def get_notifs():
    if 'user_id' not in session:
        return [], 0
    try:
        r = sb().table('notifications').select('*')\
            .eq('user_id', session['user_id']).order('created_at', desc=True).limit(10).execute()
        notifs = r.data or []
        unread = sum(1 for n in notifs if not n.get('read'))
        return notifs, unread
    except Exception:
        return [], 0

def add_notif(uid, title, msg, t='info'):
    try:
        sb().table('notifications').insert({
            'user_id': uid, 'title': title, 'message': msg, 'type': t
        }).execute()
    except Exception:
        pass

def save_upload(file_obj, prefix):
    """Encode le fichier en base64 → data URI stockée directement en DB.
    Fonctionne sur Vercel, Railway ou tout hébergeur sans filesystem.
    Taille max : 500 KB recommandé (2 MB accepté par Supabase TEXT).
    """
    if not file_obj or not file_obj.filename or not allowed_file(file_obj.filename):
        return None
    try:
        import base64
        ext  = file_obj.filename.rsplit('.', 1)[1].lower()
        mime_map = {'jpg':'image/jpeg', 'jpeg':'image/jpeg',
                    'png':'image/png',  'gif':'image/gif',
                    'webp':'image/webp','pdf':'application/pdf'}
        mime = mime_map.get(ext, f'image/{ext}')
        data = file_obj.read()
        b64  = base64.b64encode(data).decode('utf-8')
        return f'data:{mime};base64,{b64}'
    except Exception as e:
        app.logger.error(f"[save_upload] Erreur encodage: {e}")
        return None

# ─── PUBLIC ───────────────────────────────────
@app.route('/')
def index():
    try:
        r = sb().table('vehicles').select('*').neq('status', 'hors_service').execute()
        vehicles = r.data or []
    except Exception as e:
        app.logger.error(f"index vehicles error: {e}")
        vehicles = []
    try:
        stats = {
            'dispo': sum(1 for v in vehicles if v['status'] == 'disponible'),
            'clients': sb().table('users').select('id', count='exact').eq('role', 'client').execute().count or 0,
            'locations': sb().table('reservations').select('id', count='exact').eq('status', 'terminee').execute().count or 0
        }
    except Exception:
        stats = {'dispo': 0, 'clients': 0, 'locations': 0}
    notifs, unread = get_notifs()
    return render_template('index.html', vehicles=vehicles[:6], stats=stats,
                           notifs=notifs, unread=unread)

@app.route('/catalogue')
def catalogue():
    category  = request.args.get('category', '')
    fuel      = request.args.get('fuel', '')
    max_price = request.args.get('max_price', '')
    date_start= request.args.get('date_start', '')
    date_end  = request.args.get('date_end', '')
    vehicles, categories, fuels = [], [], []
    try:
        q = sb().table('vehicles').select('*')
        if category:  q = q.eq('category', category)
        if fuel:      q = q.eq('fuel', fuel)
        if max_price: q = q.lte('price_per_day', float(max_price))
        vehicles = q.execute().data or []
        if date_start and date_end:
            booked = sb().table('reservations').select('vehicle_id')\
                .not_.in_('status', ['annulee','refusee'])\
                .lte('date_start', date_end).gte('date_end', date_start).execute()
            booked_ids = {b['vehicle_id'] for b in (booked.data or [])}
            vehicles = [v for v in vehicles if v['id'] not in booked_ids]
        else:
            vehicles = [v for v in vehicles if v['status'] != 'hors_service']
        all_v = sb().table('vehicles').select('category,fuel').execute().data or []
        categories = sorted({v['category'] for v in all_v if v.get('category')})
        fuels      = sorted({v['fuel']     for v in all_v if v.get('fuel')})
    except Exception as e:
        app.logger.error(f"catalogue error: {e}")
    notifs, unread = get_notifs()
    return render_template('catalogue.html', vehicles=vehicles,
                           categories=[{'category': c} for c in categories],
                           fuels=[{'fuel': f} for f in fuels],
                           notifs=notifs, unread=unread,
                           filters={'category': category, 'fuel': fuel,
                                    'max_price': max_price, 'date_start': date_start,
                                    'date_end': date_end})

@app.route('/vehicule/<int:vid>')
def vehicle_detail(vid):
    r = sb().table('vehicles').select('*').eq('id', vid).single().execute()
    vehicle = r.data
    if not vehicle:
        flash('Véhicule introuvable.', 'error')
        return redirect(url_for('catalogue'))
    reviews_r = sb().table('reviews').select('*, users(first_name,last_name)')\
        .eq('vehicle_id', vid).order('created_at', desc=True).limit(10).execute()
    reviews = reviews_r.data or []
    # flatten join
    for rv in reviews:
        if rv.get('users'):
            rv['first_name'] = rv['users']['first_name']
            rv['last_name']  = rv['users']['last_name']
    avg = None
    if reviews:
        notes = [(rv.get('comfort_note',0)+rv.get('cleanliness_note',0)+
                  rv.get('reliability_note',0)+rv.get('service_note',0))/4
                 for rv in reviews if rv.get('comfort_note')]
        if notes:
            avg = {'avg_note': round(sum(notes)/len(notes), 1), 'total': len(notes)}
    user = get_user()
    notifs, unread = get_notifs()
    return render_template('vehicle_detail.html', vehicle=vehicle, reviews=reviews,
                           avg=avg, user=user, notifs=notifs, unread=unread)

# ─── AUTH ──────────────────────────────────────
@app.route('/inscription', methods=['GET','POST'])
def register():
    if request.method == 'POST':
        email = request.form['email'].strip().lower()
        existing = sb().table('users').select('id').eq('email', email).execute()
        if existing.data:
            flash('Cet e-mail est déjà utilisé.', 'error')
            return render_template('register.html')
        r = sb().table('users').insert({
            'email': email,
            'password_hash': generate_password_hash(request.form['password']),
            'first_name': request.form['first_name'].strip(),
            'last_name': request.form['last_name'].strip(),
            'phone': request.form.get('phone','').strip(),
            'role': 'client',
            'doc_status': 'aucun'
        }).execute()
        user = r.data[0]
        session.update({'user_id': user['id'], 'role': 'client', 'name': user['first_name']})
        add_notif(user['id'], 'Bienvenue !',
            'Compte créé. Déposez vos documents pour activer les réservations.')
        flash('Compte créé ! Déposez vos documents pour réserver.', 'success')
        return redirect(url_for('dashboard'))
    return render_template('register.html')

@app.route('/connexion', methods=['GET','POST'])
def login():
    if request.method == 'POST':
        email = request.form['email'].strip().lower()
        r = sb().table('users').select('*').eq('email', email).execute()
        users = r.data or []
        if not users or not check_password_hash(users[0]['password_hash'], request.form['password']):
            flash('Email ou mot de passe incorrect.', 'error')
            return render_template('login.html')
        u = users[0]
        session.update({'user_id': u['id'], 'role': u['role'], 'name': u['first_name']})
        return redirect(url_for('admin_dashboard') if u['role'] == 'admin' else url_for('dashboard'))
    return render_template('login.html')

@app.route('/deconnexion')
def logout():
    session.clear()
    return redirect(url_for('index'))

# ─── CLIENT ───────────────────────────────────
@app.route('/espace-client')
@login_required
def dashboard():
    user = get_user()
    res_r = sb().table('reservations').select('*, vehicles(brand,model,plate,price_per_day,image), invoices(id,status)')\
        .eq('user_id', user['id']).order('created_at', desc=True).execute()
    reservations = []
    for res in (res_r.data or []):
        v = res.get('vehicles') or {}
        i = res.get('invoices') or [{}]
        i = i[0] if isinstance(i, list) else i
        reservations.append({**res, **v,
            'invoice_id': i.get('id'), 'invoice_status': i.get('status')})
    notifs, unread = get_notifs()
    return render_template('dashboard.html', user=user, reservations=reservations,
                           notifs=notifs, unread=unread)

@app.route('/documents', methods=['GET','POST'])
@login_required
def upload_documents():
    user = get_user()
    if request.method == 'POST':
        updates = {}
        for field in ['permis', 'cni', 'justif']:
            fname = save_upload(request.files.get(field), f"doc_{user['id']}_{field}")
            if fname:
                updates[f'doc_{field}'] = fname
        if updates:
            has_p = updates.get('doc_permis') or user.get('doc_permis')
            has_c = updates.get('doc_cni')    or user.get('doc_cni')
            has_j = updates.get('doc_justif') or user.get('doc_justif')
            if has_p and has_c and has_j:
                updates.update({'doc_status': 'en_attente',
                                'doc_submitted_at': datetime.now().isoformat()})
            sb().table('users').update(updates).eq('id', user['id']).execute()
            admins = sb().table('users').select('id').eq('role','admin').execute().data or []
            for adm in admins:
                add_notif(adm['id'], 'Nouveau dossier documentaire',
                    f"{user['first_name']} {user['last_name']} a soumis ses documents.", 'warning')
            flash('Documents envoyés ! En attente de validation.', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Sélectionnez au moins un fichier valide (PDF, JPG, PNG).', 'error')
    notifs, unread = get_notifs()
    return render_template('upload_documents.html', user=user, notifs=notifs, unread=unread)

@app.route('/reserver/<int:vid>', methods=['GET','POST'])
@login_required
def reserve(vid):
    user = get_user()
    r = sb().table('vehicles').select('*').eq('id', vid).single().execute()
    vehicle = r.data
    if not vehicle:
        flash('Véhicule introuvable.', 'error')
        return redirect(url_for('catalogue'))
    if request.method == 'POST':
        date_start = request.form['date_start']
        date_end   = request.form['date_end']
        ds, de = date.fromisoformat(date_start), date.fromisoformat(date_end)
        if de <= ds:
            flash('La date de fin doit être après la date de début.', 'error')
        else:
            conflict = sb().table('reservations').select('id')\
                .eq('vehicle_id', vid)\
                .not_.in_('status', ['annulee','refusee'])\
                .lte('date_start', date_end).gte('date_end', date_start).execute()
            if conflict.data:
                flash("Ce véhicule n'est pas disponible sur cette période.", 'error')
            else:
                days  = (de - ds).days
                total = days * float(vehicle['price_per_day'])
                # Upload docs joints à la réservation si fournis
                doc_permis = save_upload(request.files.get('doc_permis'),
                                         f"res_{user['id']}_permis")
                doc_cni    = save_upload(request.files.get('doc_cni'),
                                         f"res_{user['id']}_cni")
                if doc_permis or doc_cni:
                    doc_updates = {}
                    if doc_permis: doc_updates['doc_permis'] = doc_permis
                    if doc_cni:    doc_updates['doc_cni']    = doc_cni
                    fresh = sb().table('users').select('doc_permis,doc_cni,doc_justif')\
                        .eq('id', user['id']).single().execute().data or {}
                    if (doc_updates.get('doc_permis') or fresh.get('doc_permis')) and \
                       (doc_updates.get('doc_cni') or fresh.get('doc_cni')):
                        doc_updates.update({'doc_status': 'en_attente',
                                            'doc_submitted_at': datetime.now().isoformat()})
                    sb().table('users').update(doc_updates).eq('id', user['id']).execute()

                sb().table('reservations').insert({
                    'user_id': user['id'], 'vehicle_id': vid,
                    'date_start': date_start, 'date_end': date_end,
                    'total_price': total, 'status': 'en_attente',
                    'notes': request.form.get('notes','')
                }).execute()
                add_notif(user['id'], 'Demande reçue ✓',
                    f"Votre demande pour {vehicle['brand']} {vehicle['model']} a été transmise.")
                admins = sb().table('users').select('id').eq('role','admin').execute().data or []
                for adm in admins:
                    add_notif(adm['id'], 'Nouvelle réservation',
                        f"{user['first_name']} {user['last_name']} — "
                        f"{vehicle['brand']} {vehicle['model']} du {date_start} au {date_end}")
                flash('Réservation soumise !', 'success')
                return redirect(url_for('dashboard'))
    notifs, unread = get_notifs()
    return render_template('reserve.html', vehicle=vehicle, user=user,
                           notifs=notifs, unread=unread)

@app.route('/annuler-reservation/<int:rid>', methods=['POST'])
@login_required
def cancel_reservation(rid):
    user = get_user()
    r = sb().table('reservations').select('*').eq('id', rid)\
        .eq('user_id', user['id']).execute()
    res = (r.data or [None])[0]
    if res and res['status'] in ('en_attente','confirmee'):
        sb().table('reservations').update({'status':'annulee'}).eq('id', rid).execute()
        flash('Réservation annulée.', 'success')
    else:
        flash("Impossible d'annuler cette réservation.", 'error')
    return redirect(url_for('dashboard'))

@app.route('/avis/<int:rid>', methods=['GET','POST'])
@login_required
def leave_review(rid):
    user = get_user()
    r = sb().table('reservations').select('*, vehicles(brand,model)')\
        .eq('id', rid).eq('user_id', user['id']).eq('status','terminee').execute()
    res_list = r.data or []
    if not res_list:
        flash('Réservation introuvable ou non terminée.', 'error')
        return redirect(url_for('dashboard'))
    res = {**res_list[0], **(res_list[0].get('vehicles') or {})}
    if sb().table('reviews').select('id').eq('reservation_id', rid).execute().data:
        flash('Vous avez déjà laissé un avis.', 'info')
        return redirect(url_for('dashboard'))
    if request.method == 'POST':
        sb().table('reviews').insert({
            'reservation_id': rid,
            'user_id': user['id'],
            'vehicle_id': res_list[0]['vehicle_id'],
            'comfort_note':     int(request.form.get('comfort_note', 5)),
            'cleanliness_note': int(request.form.get('cleanliness_note', 5)),
            'reliability_note': int(request.form.get('reliability_note', 5)),
            'service_note':     int(request.form.get('service_note', 5)),
            'comment': request.form.get('comment','')
        }).execute()
        flash('Merci pour votre avis !', 'success')
        return redirect(url_for('dashboard'))
    notifs, unread = get_notifs()
    return render_template('review.html', reservation=res, notifs=notifs, unread=unread)

@app.route('/notifications/lues', methods=['POST'])
@login_required
def mark_notifications_read():
    sb().table('notifications').update({'read': True})\
        .eq('user_id', session['user_id']).execute()
    return jsonify({'ok': True})

# ─── ADMIN ─────────────────────────────────────
@app.route('/admin')
@admin_required
def admin_dashboard():
    supa = sb()
    total_clients    = supa.table('users').select('id',count='exact').eq('role','client').execute().count or 0
    docs_pending     = supa.table('users').select('id',count='exact').eq('doc_status','en_attente').execute().count or 0
    total_vehicles   = supa.table('vehicles').select('id',count='exact').execute().count or 0
    vehicles_dispo   = supa.table('vehicles').select('id',count='exact').eq('status','disponible').execute().count or 0
    res_pending      = supa.table('reservations').select('id',count='exact').eq('status','en_attente').execute().count or 0
    total_completed  = supa.table('reservations').select('id',count='exact').eq('status','terminee').execute().count or 0
    rev_r = supa.table('reservations').select('total_price').eq('status','terminee').execute()
    total_revenue    = sum(r['total_price'] for r in (rev_r.data or []) if r.get('total_price'))

    stats = {
        'total_clients': total_clients, 'docs_pending': docs_pending,
        'total_vehicles': total_vehicles, 'vehicles_dispo': vehicles_dispo,
        'reservations_pending': res_pending, 'total_completed': total_completed,
        'total_revenue': round(total_revenue, 2)
    }
    recent_r = supa.table('reservations')\
        .select('*, users(first_name,last_name), vehicles(brand,model)')\
        .order('created_at', desc=True).limit(8).execute()
    recent_res = []
    for res in (recent_r.data or []):
        u = res.get('users') or {}
        v = res.get('vehicles') or {}
        recent_res.append({**res, **u, **v})

    pending_r = supa.table('users').select('*').eq('doc_status','en_attente')\
        .order('doc_submitted_at', desc=True).execute()
    pending_docs = pending_r.data or []
    notifs, unread = get_notifs()
    return render_template('admin/dashboard.html', stats=stats, recent_res=recent_res,
                           pending_docs=pending_docs, notifs=notifs, unread=unread)

@app.route('/admin/clients')
@admin_required
def admin_clients():
    status_filter = request.args.get('status','')
    q = sb().table('users').select('*').eq('role','client')
    if status_filter:
        q = q.eq('doc_status', status_filter)
    clients = q.order('created_at', desc=True).execute().data or []
    notifs, unread = get_notifs()
    return render_template('admin/clients.html', clients=clients,
                           status_filter=status_filter, notifs=notifs, unread=unread)

@app.route('/admin/client/<int:uid>')
@admin_required
def admin_client_detail(uid):
    client = sb().table('users').select('*').eq('id', uid).single().execute().data
    if not client:
        flash('Client introuvable.', 'error')
        return redirect(url_for('admin_clients'))
    res_r = sb().table('reservations').select('*, vehicles(brand,model)')\
        .eq('user_id', uid).order('created_at', desc=True).execute()
    reservations = [{**r, **(r.get('vehicles') or {})} for r in (res_r.data or [])]
    notifs, unread = get_notifs()
    return render_template('admin/client_detail.html', client=client,
                           reservations=reservations, notifs=notifs, unread=unread)

@app.route('/admin/valider-documents/<int:uid>', methods=['POST'])
@admin_required
def validate_documents(uid):
    action = request.form.get('action')
    reason = request.form.get('reason','')
    admin  = get_user()
    now    = datetime.now().isoformat()
    validator = f"{admin['first_name']} {admin['last_name']}"
    if action == 'approve':
        sb().table('users').update({
            'doc_status': 'approuve', 'doc_validated_at': now,
            'doc_validator': validator, 'doc_reject_reason': None
        }).eq('id', uid).execute()
        add_notif(uid, 'Documents approuvés ✓',
            'Vos documents ont été validés. Vous pouvez maintenant réserver !', 'success')
        flash('Documents approuvés.', 'success')
    elif action == 'reject':
        sb().table('users').update({
            'doc_status': 'rejete', 'doc_validated_at': now,
            'doc_validator': validator, 'doc_reject_reason': reason
        }).eq('id', uid).execute()
        add_notif(uid, 'Documents refusés',
            f'Motif : {reason}. Veuillez re-soumettre vos documents.', 'error')
        flash('Documents refusés.', 'warning')
    return redirect(url_for('admin_client_detail', uid=uid))

@app.route('/admin/reservations')
@admin_required
def admin_reservations():
    status_filter = request.args.get('status','')
    q = sb().table('reservations')\
        .select('*, users(first_name,last_name,email), vehicles(brand,model,plate)')
    if status_filter:
        q = q.eq('status', status_filter)
    r = q.order('created_at', desc=True).execute()
    reservations = [{**res, **(res.get('users') or {}), **(res.get('vehicles') or {})}
                    for res in (r.data or [])]
    notifs, unread = get_notifs()
    return render_template('admin/reservations.html', reservations=reservations,
                           status_filter=status_filter, notifs=notifs, unread=unread)

@app.route('/admin/reservation/<int:rid>/action', methods=['POST'])
@admin_required
def admin_reservation_action(rid):
    action = request.form.get('action')
    r = sb().table('reservations').select('*').eq('id', rid).single().execute()
    res = r.data
    if not res:
        flash('Réservation introuvable.', 'error')
        return redirect(url_for('admin_reservations'))
    status_map = {'confirmer':'confirmee','refuser':'refusee',
                  'terminer':'terminee','annuler':'annulee'}
    new_status = status_map.get(action)
    if new_status:
        sb().table('reservations').update({'status': new_status}).eq('id', rid).execute()
        if new_status == 'terminee':
            sb().table('invoices').insert({
                'reservation_id': rid, 'user_id': res['user_id'],
                'amount': res['total_price'], 'status': 'emise'
            }).execute()
            add_notif(res['user_id'], 'Location terminée — Merci !',
                'Votre location est terminée. Laissez un avis sur votre expérience !', 'success')
        elif new_status == 'confirmee':
            add_notif(res['user_id'], 'Réservation confirmée ✓', 'Bonne route !', 'success')
        elif new_status == 'refusee':
            add_notif(res['user_id'], 'Réservation refusée',
                'Contactez le support au 77 672 97 40 pour plus d\'informations.', 'error')
        flash(f'Réservation : {new_status}.', 'success')
    return redirect(url_for('admin_reservations'))

@app.route('/admin/vehicules')
@admin_required
def admin_vehicles():
    vehicles = sb().table('vehicles').select('*').execute().data or []
    notifs, unread = get_notifs()
    return render_template('admin/vehicles.html', vehicles=vehicles,
                           notifs=notifs, unread=unread)

@app.route('/admin/vehicule/ajouter', methods=['GET','POST'])
@admin_required
def admin_add_vehicle():
    if request.method == 'POST':
        image = save_upload(request.files.get('image'), 'vehicle')
        sb().table('vehicles').insert({
            'brand': request.form['brand'], 'model': request.form['model'],
            'plate': request.form['plate'], 'category': request.form['category'],
            'year': int(request.form['year']), 'color': request.form['color'],
            'seats': int(request.form.get('seats',5)),
            'fuel': request.form['fuel'], 'transmission': request.form['transmission'],
            'price_per_day': float(request.form['price_per_day']),
            'description': request.form.get('description',''),
            'status': request.form.get('status','disponible'),
            'image': image, 'mileage': int(request.form.get('mileage',0))
        }).execute()
        flash('Véhicule ajouté.', 'success')
        return redirect(url_for('admin_vehicles'))
    notifs, unread = get_notifs()
    return render_template('admin/vehicle_form.html', vehicle=None,
                           notifs=notifs, unread=unread)

@app.route('/admin/vehicule/<int:vid>/modifier', methods=['GET','POST'])
@admin_required
def admin_edit_vehicle(vid):
    vehicle = sb().table('vehicles').select('*').eq('id',vid).single().execute().data
    if not vehicle:
        flash('Véhicule introuvable.', 'error')
        return redirect(url_for('admin_vehicles'))
    if request.method == 'POST':
        image = save_upload(request.files.get('image'), f'vehicle_{vid}') or vehicle['image']
        sb().table('vehicles').update({
            'brand': request.form['brand'], 'model': request.form['model'],
            'plate': request.form['plate'], 'category': request.form['category'],
            'year': int(request.form['year']), 'color': request.form['color'],
            'seats': int(request.form.get('seats',5)),
            'fuel': request.form['fuel'], 'transmission': request.form['transmission'],
            'price_per_day': float(request.form['price_per_day']),
            'description': request.form.get('description',''),
            'status': request.form.get('status','disponible'),
            'image': image, 'mileage': int(request.form.get('mileage',0))
        }).eq('id', vid).execute()
        flash('Véhicule modifié.', 'success')
        return redirect(url_for('admin_vehicles'))
    notifs, unread = get_notifs()
    return render_template('admin/vehicle_form.html', vehicle=vehicle,
                           notifs=notifs, unread=unread)

@app.route('/admin/statistiques')
@admin_required
def admin_stats():
    supa = sb()
    res_done = supa.table('reservations').select('*').eq('status','terminee').execute().data or []
    # Revenue par mois
    from collections import defaultdict
    monthly = defaultdict(lambda: {'revenue':0,'count':0})
    for r in res_done:
        m = (r.get('created_at') or '')[:7]
        monthly[m]['revenue'] += r.get('total_price',0)
        monthly[m]['count']   += 1
    revenue_monthly = [{'month':k,'revenue':round(v['revenue'],2),'count':v['count']}
                       for k,v in sorted(monthly.items(), reverse=True)[:6]]

    vehicles = supa.table('vehicles').select('*').execute().data or []
    top_vehicles = sorted(vehicles, key=lambda v: v.get('id',0))[:8]
    by_category_d = defaultdict(lambda: {'rentals':0,'revenue':0})
    for r in res_done:
        v = next((vv for vv in vehicles if vv['id']==r['vehicle_id']), {})
        cat = v.get('category','?')
        by_category_d[cat]['rentals'] += 1
        by_category_d[cat]['revenue'] += r.get('total_price',0)
    by_category = [{'category':k,'rentals':v['rentals'],'revenue':round(v['revenue'],2)}
                   for k,v in by_category_d.items()]

    notifs, unread = get_notifs()
    return render_template('admin/stats.html',
        revenue_monthly=revenue_monthly, top_vehicles=top_vehicles,
        by_category=by_category, satisfaction=[], utilization=[],
        notifs=notifs, unread=unread)

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    # Fallback local uniquement (les fichiers Supabase ont une URL complète)
    return send_from_directory(os.path.join(_root, 'static', 'uploads'), filename)

# ─── GESTIONNAIRES D'ERREUR ────────────────────
@app.errorhandler(500)
def internal_error(e):
    import traceback
    app.logger.error(f"500 error: {traceback.format_exc()}")
    return f"""<!DOCTYPE html>
<html><body style="font-family:monospace;padding:40px;background:#111827;color:#f9fafb">
<h2 style="color:#f87171">Erreur 500 — Détail</h2>
<pre style="background:#1f2d42;padding:20px;border-radius:8px;color:#fbbf24;overflow:auto">{str(e)}</pre>
<p><a href="/" style="color:#10b981">← Retour</a></p>
</body></html>""", 500

@app.errorhandler(404)
def not_found(e):
    return redirect(url_for('index'))

# ─── BOOT ──────────────────────────────────────
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)
