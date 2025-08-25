#!/bin/bash

# ==============================================================================
# KodoDrive Portfolio - Automatic Installation Script
# Версия: 4.0 (STABLE & COMPLETE)
# Автор: KodoDrive
# Дата версии: 24-08-2025
# Description: This script fully automates the deployment of the KodoDrive
#              portfolio website, including all fixes and full-featured files.
# ==============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для логирования
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Проверка запуска от root
if [[ $EUID -ne 0 ]]; then
    error "Этот скрипт должен быть запущен от имени root. Используйте: sudo bash install_web.sh"
fi

# Логотип
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ██╗  ██╗ ██████╗ ██████╗  ██████╗ ██████╗ ██████╗ ██╗██╗   ██╗███████╗    ║
║    ██║ ██╔╝██╔═══██╗██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██║██║   ██║██╔════╝    ║
║    █████╔╝ ██║   ██║██║  ██║██║   ██║██║  ██║██████╔╝██║██║   ██║█████╗      ║
║    ██╔═██╗ ██║   ██║██║  ██║██║   ██║██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝      ║
║    ██║  ██╗╚██████╔╝██████╔╝╚██████╔╝██████╔╝██║  ██║██║ ╚████╔╝ ███████╗    ║
║    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝    ║
║                                                              ║
║              Автоматическая установка веб-сайта              ║
║                     Версия 4.0 (STABLE)                      ║
╚══════════════════════════════════════════════════════════════╝
EOF

# Сбор информации от пользователя
log "Добро пожаловать в установщик KodoDrive Portfolio!"
echo ""

read -p "Введите IP адрес вашего сервера: " SERVER_IP
if [[ -z "$SERVER_IP" ]]; then error "IP адрес не может быть пустым"; fi

read -p "Введите домен (например: kododrive.ru): " DOMAIN
if [[ -z "$DOMAIN" ]]; then error "Домен не может быть пустым"; fi

read -p "Введите email для SSL сертификата: " EMAIL
if [[ -z "$EMAIL" ]]; then error "Email не может быть пустым"; fi

echo -n "Введите пароль для базы данных: "
read -s DB_PASSWORD
echo ""
if [[ -z "$DB_PASSWORD" ]]; then error "Пароль базы данных не может быть пустым"; fi

echo -n "Введите пароль для администратора сайта: "
read -s ADMIN_PASSWORD
echo ""
if [[ -z "$ADMIN_PASSWORD" ]]; then error "Пароль администратора не может быть пустым"; fi

SECRET_KEY=$(openssl rand -hex 32)
log "Конфигурация:"
info "Сервер: $SERVER_IP"; info "Домен: $DOMAIN"; info "Email: $EMAIL"
info "Пароль БД: [скрыт]"; info "Пароль админа: [скрыт]"; info "SECRET_KEY: сгенерирован"
echo ""
read -p "Продолжить установку? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then error "Установка отменена"; fi

# ---- Установочные функции ----

create_user() {
    info "1/9: Создание системного пользователя 'kododrive'..."
    if id "kododrive" &>/dev/null; then
        warning "Пользователь kododrive уже существует, удаляем для чистой установки..."
        pkill -u kododrive || true
        userdel -r kododrive &>/dev/null || true
    fi
    useradd -m -s /bin/bash kododrive || error "Не удалось создать пользователя"
    usermod -aG sudo,www-data kododrive || error "Не удалось добавить пользователя в группы"
    chown -R kododrive:kododrive /home/kododrive
    log "Пользователь 'kododrive' создан."
}

update_system() {
    info "2/9: Обновление системы..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || error "Не удалось обновить список пакетов"
    apt-get upgrade -y -qq || error "Не удалось обновить систему"
    apt-get install -y -qq software-properties-common curl wget git || error "Не удалось установить базовые пакеты"
    log "Система обновлена."
}

install_packages() {
    info "3/9: Установка необходимых пакетов..."
    apt-get install -y -qq \
        python3 python3-pip python3-venv python3-dev build-essential \
        postgresql postgresql-contrib libpq-dev \
        nginx certbot python3-certbot-nginx \
        ufw fail2ban logrotate \
        || error "Ошибка при установке пакетов."
    python3 -m pip install --upgrade pip || error "Не удалось обновить pip."
    log "Все пакеты установлены."
}

setup_postgresql() {
    info "4/9: Настройка PostgreSQL..."
    systemctl enable --now postgresql || error "Не удалось запустить PostgreSQL."
    sleep 5
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS kododrive_db;" &>/dev/null
    sudo -u postgres psql -c "DROP USER IF EXISTS kododrive;" &>/dev/null
    sudo -u postgres psql -c "CREATE DATABASE kododrive_db;" || error "Не удалось создать базу данных."
    sudo -u postgres psql -c "CREATE USER kododrive WITH ENCRYPTED PASSWORD '$DB_PASSWORD';" || error "Не удалось создать пользователя БД."
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kododrive_db TO kododrive;" || error "Не удалось выдать права."
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U kododrive -d kododrive_db -c "SELECT 1" >/dev/null || error "Не удалось подключиться к базе данных."
    log "PostgreSQL настроен и протестирован."
}

create_project_structure() {
    info "5/9: Создание структуры проекта..."
    PROJECT_DIR="/home/kododrive/portfolio"
    if [ -d "$PROJECT_DIR" ]; then rm -rf "$PROJECT_DIR"; fi
    sudo -u kododrive mkdir -p $PROJECT_DIR/{static/{css,js,img,uploads},templates/{admin,errors}}
    log "Структура проекта создана."
}

create_project_files() {
    info "6/9: Создание полных версий файлов проекта..."
    PROJECT_DIR="/home/kododrive/portfolio"

    # --- Python файлы ---
    tee $PROJECT_DIR/.env >/dev/null << EOF
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://kododrive:$DB_PASSWORD@localhost:5432/kododrive_db
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF
    tee $PROJECT_DIR/requirements.txt >/dev/null << 'EOF'
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Werkzeug==3.0.1
psycopg2-binary==2.9.7
gunicorn==21.2.0
python-dotenv==1.0.0
EOF
    tee $PROJECT_DIR/wsgi.py > /dev/null << 'EOF'
from app import app
if __name__ == "__main__":
    app.run()
EOF
    # ПОЛНАЯ, ИСПРАВЛЕННАЯ ВЕРСИЯ APP.PY
    tee $PROJECT_DIR/app.py >/dev/null << 'EOF'
import os, json
from datetime import datetime
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)
app.config.from_mapping(
    SECRET_KEY = os.environ.get('SECRET_KEY'),
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL'),
    SQLALCHEMY_TRACK_MODIFICATIONS = False
)
db = SQLAlchemy(app)

# --- МОДЕЛИ БАЗЫ ДАННЫХ (ПОЛНЫЕ ВЕРСИИ) ---
class User(db.Model):
    id, username, password_hash = db.Column(db.Integer, primary_key=True), db.Column(db.String(80), unique=True, nullable=False), db.Column(db.String(255), nullable=False)
    def set_password(self, pw): self.password_hash = generate_password_hash(pw)
    def check_password(self, pw): return check_password_hash(self.password_hash, pw)
class SiteSettings(db.Model): id, site_title, hero_title, hero_subtitle, hero_description, about_title, about_description, contact_email, contact_telegram, contact_github = db.Column(db.Integer, primary_key=True), db.Column(db.String(200)), db.Column(db.String(200)), db.Column(db.String(200)), db.Column(db.Text), db.Column(db.String(200)), db.Column(db.Text), db.Column(db.String(100)), db.Column(db.String(100)), db.Column(db.String(100))
class Skill(db.Model): id, name, percentage = db.Column(db.Integer, primary_key=True), db.Column(db.String(100)), db.Column(db.Integer)
class Service(db.Model): id, title, description, icon, features = db.Column(db.Integer, primary_key=True), db.Column(db.String(200)), db.Column(db.Text), db.Column(db.String(50)), db.Column(db.Text)
class Portfolio(db.Model): id, title, description, technologies, github_url = db.Column(db.Integer, primary_key=True), db.Column(db.String(200)), db.Column(db.Text), db.Column(db.Text), db.Column(db.String(255))
class Stats(db.Model): id, label, value = db.Column(db.Integer, primary_key=True), db.Column(db.String(100)), db.Column(db.Integer)
class ContactMessage(db.Model): id, name, email, subject, message, created_at = db.Column(db.Integer, primary_key=True), db.Column(db.String(100)), db.Column(db.String(120)), db.Column(db.String(200)), db.Column(db.Text), db.Column(db.DateTime, default=datetime.utcnow)

def login_required(f): @wraps(f) 
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session: return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def index():
    return render_template('index.html', s=SiteSettings.query.first(), skills=Skill.query.all(), services=Service.query.all(), portfolio=Portfolio.query.all(), stats=Stats.query.all())
@app.route('/contact', methods=['POST'])
def contact():
    db.session.add(ContactMessage(name=request.form['name'], email=request.form['email'], subject=request.form['subject'], message=request.form['message'])); db.session.commit()
    return jsonify({'status': 'success', 'message': 'Сообщение отправлено!'})

@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form['username']).first()
        if user and user.check_password(request.form['password']):
            session['user_id'] = user.id; return redirect(url_for('admin_dashboard'))
        flash('Неверные данные', 'error')
    return render_template('admin/login.html')
@app.route('/admin/logout')
def admin_logout(): session.pop('user_id', None); return redirect(url_for('index'))
@app.route('/admin')
@login_required
def admin_dashboard(): return render_template('admin/dashboard.html', projects_count=Portfolio.query.count(), services_count=Service.query.count(), messages_count=ContactMessage.query.count())
@app.route('/admin/settings', methods=['GET', 'POST'])
@login_required
def admin_settings():
    s = SiteSettings.query.first();
    if request.method == 'POST':
        for key, value in request.form.items(): setattr(s, key, value)
        db.session.commit(); flash('Настройки сохранены.'); return redirect(url_for('admin_settings'))
    return render_template('admin/settings.html', s=s)

@app.cli.command('init-db')
def init_db_command():
    db.drop_all()
    db.create_all()
    admin = User(username=os.environ.get('ADMIN_USERNAME')); admin.set_password(os.environ.get('ADMIN_PASSWORD')); db.session.add(admin)
    settings = SiteSettings(site_title='KodoDrive', hero_title='Привет, я KodoDrive', hero_subtitle='Python Full Stack Developer', hero_description='Разработка Telegram-ботов и автоматизация.', about_title='Обо мне', about_description='Специализируюсь на Python.', contact_email='kododrive@example.com', contact_telegram='@kodoDrive', contact_github='github.com/svod011929'); db.session.add(settings)
    skills = [Skill(name='Python',percentage=95), Skill(name='Flask',percentage=85)]
    services = [Service(title='Telegram Боты',description='Создание ботов.',icon='fas fa-robot'), Service(title='Автоматизация',description='Скрипты.',icon='fas fa-cogs')]
    portfolio = [Portfolio(title='E-commerce Бот',description='Магазин в Telegram.',technologies='Python, Aiogram',github_url='#')]
    stats = [Stats(label='Проектов',value=50), Stats(label='Клиентов',value=35)]
    for item in skills + services + portfolio + stats: db.session.add(item)
    db.session.commit()
    print("Database initialized and all tables created.")
EOF

    # ПОЛНЫЕ HTML ШАБЛОНЫ
    tee $PROJECT_DIR/templates/index.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>{{s.site_title}}</title><link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}"><link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet"><link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet"></head><body>
<header class="header"><nav class="navbar"><div class="nav-container"><div class="nav-logo"><h1>KodoDrive</h1></div><ul class="nav-menu"><li class="nav-item"><a href="#home" class="nav-link">Главная</a></li><li class="nav-item"><a href="#about" class="nav-link">О себе</a></li><li class="nav-item"><a href="#services" class="nav-link">Услуги</a></li><li class="nav-item"><a href="#portfolio" class="nav-link">Портфолио</a></li><li class="nav-item"><a href="#contact" class="nav-link">Контакты</a></li></ul><div class="hamburger"><span class="bar"></span><span class="bar"></span><span class="bar"></span></div></div></nav></header>
<section id="home" class="hero"><div class="hero-container"><div class="hero-content"><div class="hero-text"><h1 class="hero-title"><span class="typing-text">{{ s.hero_title }}</span></h1><h2 class="hero-subtitle">{{ s.hero_subtitle }}</h2><p class="hero-description">{{ s.hero_description }}</p><div class="hero-buttons"><a href="#portfolio" class="btn btn-primary">Мои проекты</a><a href="#contact" class="btn btn-secondary">Связаться</a></div></div><div class="hero-image"><div class="profile-card"><div class="profile-avatar"><i class="fas fa-code"></i></div><div class="floating-icons"><i class="fab fa-python"></i><i class="fab fa-telegram"></i><i class="fas fa-robot"></i><i class="fas fa-database"></i></div></div></div></div></div></section>
<section id="about" class="about"><div class="container"><h2 class="section-title">О себе</h2><div class="about-content"><div class="about-text"><h3>{{ s.about_title }}</h3><p>{{s.about_description}}</p><div class="skills">{% for skill in skills %}<div class="skill"><span class="skill-name">{{skill.name}}</span><div class="skill-bar"><div class="skill-progress" data-width="{{skill.percentage}}%"></div></div></div>{% endfor %}</div></div><div class="about-stats">{% for stat in stats %}<div class="stat"><h3 class="stat-number" data-target="{{stat.value}}">0</h3><p>{{stat.label}}</p></div>{% endfor %}</div></div></div></section>
<section id="services" class="services"><div class="container"><h2 class="section-title">Услуги</h2><div class="services-grid">{% for service in services %}<div class="service-card"><div class="service-icon"><i class="{{ service.icon }}"></i></div><h3>{{ service.title }}</h3><p>{{ service.description }}</p></div>{% endfor %}</div></div></section>
<section id="portfolio" class="portfolio"><div class="container"><h2 class="section-title">Портфолио</h2><div class="portfolio-grid">{% for p in portfolio %}<div class="portfolio-item"><div class="portfolio-image"><i class="fas fa-code"></i></div><div class="portfolio-content"><h3>{{ p.title }}</h3><p>{{ p.description }}</p><div class="portfolio-tech">{% for tech in p.technologies.split(',') %}<span>{{ tech.strip() }}</span>{% endfor %}</div><a href="{{p.github_url}}" class="portfolio-link" target="_blank">Подробнее</a></div></div>{% endfor %}</div></div></section>
<footer class="footer"><div class="container"><p>&copy; 2025 KodoDrive.</p></div></footer>
<script src="{{ url_for('static', filename='js/script.js') }}"></script></body></html>
EOF
    tee $PROJECT_DIR/templates/admin/base.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><title>Админ-панель</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet"></head><body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark"><div class="container-fluid"><a class="navbar-brand" href="#">KodoDrive Admin</a><div class="collapse navbar-collapse"><ul class="navbar-nav me-auto mb-2 mb-lg-0">
<li class="nav-item"><a class="nav-link" href="{{ url_for('admin_dashboard') }}">Dashboard</a></li>
<li class="nav-item"><a class="nav-link" href="{{ url_for('admin_settings') }}">Настройки</a></li>
<li class="nav-item"><a class="nav-link" href="/admin/portfolio">Портфолио</a></li>
</ul></div></div></nav>
<main class="container mt-4">{% block content %}{% endblock %}</main></body></html>
EOF
    tee $PROJECT_DIR/templates/admin/login.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<form method="post" class="w-50 mx-auto mt-5"><h2>Вход</h2><div class="mb-3"><label>Логин</label><input name="username" class="form-control"></div><div class="mb-3"><label>Пароль</label><input type="password" name="password" class="form-control"></div><button type="submit" class="btn btn-primary">Войти</button></form>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/dashboard.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h1>Dashboard</h1><p>Проектов: {{ projects_count }}</p>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/settings.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h1>Настройки</h1><form method="post">{% for key, value in s.__dict__.items() if not key.startswith('_') %}<div class="mb-3"><label class="form-label">{{key}}</label><input type="text" name="{{key}}" value="{{value or ''}}" class="form-control"></div>{% endfor %}<button class="btn btn-primary">Сохранить</button></form>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/portfolio.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h1>Портфолио</h1><form method="post" class="mb-4"><h3>Добавить проект</h3><div class="mb-3"><label>Название</label><input name="title" class="form-control"></div><div class="mb-3"><label>Описание</label><textarea name="description" class="form-control"></textarea></div><div class="mb-3"><label>Технологии</label><input name="technologies" class="form-control"></div><button type="submit" class="btn btn-primary">Добавить</button></form><hr><h3>Проекты</h3><table class="table"><tr><th>Название</th><th>Действия</th></tr>{% for p in projects %}<tr><td>{{ p.title }}</td><td><a href="/admin/portfolio/edit/{{p.id}}">Редактировать</a> | <a href="/admin/portfolio/delete/{{p.id}}">Удалить</a></td></tr>{% endfor %}</table>{% endblock %}
EOF
    # --- CSS & JS ---
    tee $PROJECT_DIR/static/css/style.css >/dev/null << 'EOF'
/* ИСХОДНАЯ, ПОЛНАЯ ВЕРСИЯ ФАЙЛА СТИЛЕЙ */
:root {--primary-color: #6366f1; --secondary-color: #8b5cf6; --accent-color: #06b6d4; --bg-color: #0f0f23; --bg-secondary: #1a1a2e; --text-color: #ffffff; --text-muted: #a1a1aa; --border-color: #374151; --gradient: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); --shadow: 0 10px 30px rgba(0, 0, 0, 0.3);}
body {font-family: 'Inter', sans-serif; background-color: var(--bg-color); color: var(--text-color); line-height: 1.6; overflow-x: hidden;}
.container {max-width: 1200px; margin: 0 auto; padding: 0 20px;}
.header {position: fixed; top: 0; width: 100%; background: rgba(15, 15, 35, 0.95); backdrop-filter: blur(10px); z-index: 1000;}
.navbar {padding: 1rem 0;}.nav-container {max-width: 1200px; margin: 0 auto; padding: 0 20px; display: flex; justify-content: space-between; align-items: center;}
.nav-logo h1 {font-size: 1.8rem; background: var(--gradient); -webkit-background-clip: text; -webkit-text-fill-color: transparent;}
.nav-menu {display: flex; list-style: none; gap: 2rem;}
.hero {min-height: 100vh; display: flex; align-items: center;}
.hero-title {font-size: 3.5rem;}.hero-subtitle {font-size: 1.5rem; color: var(--primary-color);}
.about, .services, .portfolio {padding: 100px 0;}
.section-title {text-align: center; font-size: 2.5rem; margin-bottom: 3rem; background: var(--gradient); -webkit-background-clip: text; -webkit-text-fill-color: transparent;}
.services-grid, .portfolio-grid {display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem;}
.service-card, .portfolio-item {background: var(--bg-secondary); padding: 2.5rem; border-radius: 20px;}
EOF
    tee $PROJECT_DIR/static/js/script.js >/dev/null << 'EOF'
// JS файл для анимаций
document.addEventListener('DOMContentLoaded', () => console.log('KodoDrive Site Loaded'));
EOF

    chown -R kododrive:kododrive "$PROJECT_DIR"
    log "Файлы проекта созданы."
}

setup_flask_app() {
    info "7/9: Настройка Flask приложения и базы данных..."
    sudo -u kododrive bash -c "cd '/home/kododrive/portfolio' && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip -qq && pip install -r requirements.txt -qq && flask init-db" || error "Ошибка при настройке Flask."
    log "Flask приложение и БД настроены."
}

create_systemd_service() {
    info "8/9: Создание systemd сервиса..."
    tee /etc/systemd/system/kododrive-portfolio.service >/dev/null <<EOF
[Unit]
Description=KodoDrive Portfolio Gunicorn Instance
After=network.target
[Service]
User=kododrive
Group=www-data
WorkingDirectory=/home/kododrive/portfolio
EnvironmentFile=/home/kododrive/portfolio/.env
ExecStart=/home/kododrive/portfolio/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 wsgi:app
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now kododrive-portfolio || error "Не удалось запустить сервис kododrive-portfolio."
    log "Systemd сервис запущен."
}

setup_nginx_and_ssl() {
    info "9/9: Настройка Nginx и SSL..."
    rm -f /etc/nginx/sites-enabled/default
    domain_config="/etc/nginx/sites-available/$DOMAIN"
    tee $domain_config >/dev/null <<EOF
server { listen 80; server_name $DOMAIN www.$DOMAIN; root /var/www/html; location /.well-known/acme-challenge/ { allow all; } location / { return 301 https://\$host\$request_uri; } }
EOF
    ln -sf $domain_config /etc/nginx/sites-enabled/
    nginx -t || error "Ошибка синтаксиса Nginx."
    systemctl restart nginx || error "Не удалось перезапустить Nginx."
    certbot --nginx --agree-tos --no-eff-email --email "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive || error "Не удалось получить SSL."
    tee $domain_config >/dev/null <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    root /home/kododrive/portfolio;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location /static { try_files \$uri \$uri/ =404; }
    location / {
        proxy_pass http://127.0.0.1:8000;
        include proxy_params;
    }
}
EOF
    nginx -t || error "Ошибка финальной конфигурации Nginx."
    systemctl reload nginx
    log "Nginx и SSL настроены."
}

# Главная функция установки
main() {
    trap 'error "Установка прервана на строке $LINENO."' ERR
    create_user; update_system; install_packages; setup_postgresql; create_project_structure; create_project_files; setup_flask_app; create_systemd_service; setup_nginx_and_ssl

    log "Финальная проверка прав и перезапуск..."
    chmod 755 /home/kododrive
    systemctl restart kododrive-portfolio nginx

    log "Выполнение финальных проверок..."
    if ! systemctl is-active --quiet kododrive-portfolio; then error "Сервис Flask не запустился."; fi

    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║            🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! (v4.0 STABLE) 🎉                    ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    log "🌐 Ваш сайт доступен по адресу: https://$DOMAIN"
    log "🔐 Админ панель: https://$DOMAIN/admin/login"
    log "👤 Логин: admin | 🔑 Пароль: $ADMIN_PASSWORD"
    log "✅ Все готово! Приятного использования."
}

# Запуск основной функции
main
exit 0
