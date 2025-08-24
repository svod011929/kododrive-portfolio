#!/bin/bash

# ==============================================================================
# KodoDrive Portfolio - Automatic Installation Script
# Версия: 3.2 (COMPLETE & STABLE)
# Автор: KodoDrive
# Дата версии: 24-08-2025
# Description: This script fully automates the deployment of the KodoDrive
#              portfolio website, including a complete CMS backend.
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
║                     Версия 3.2 (STABLE)                      ║
╚══════════════════════════════════════════════════════════════╝

EOF

# Сбор информации от пользователя
log "Добро пожаловать в установщик KodoDrive Portfolio!"
echo ""

# Проверка операционной системы
if ! command -v apt &> /dev/null; then
    error "Этот скрипт работает только на Ubuntu/Debian системах"
fi

read -p "Введите IP адрес вашего сервера: " SERVER_IP
if [[ -z "$SERVER_IP" ]]; then
    error "IP адрес не может быть пустым"
fi

read -p "Введите домен (например: kododrive.ru): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    error "Домен не может быть пустым"
fi

read -p "Введите email для SSL сертификата: " EMAIL
if [[ -z "$EMAIL" ]]; then
    error "Email не может быть пустым"
fi

echo -n "Введите пароль для базы данных: "
read -s DB_PASSWORD
echo ""
if [[ -z "$DB_PASSWORD" ]]; then
    error "Пароль базы данных не может быть пустым"
fi

echo -n "Введите пароль для администратора сайта: "
read -s ADMIN_PASSWORD
echo ""
if [[ -z "$ADMIN_PASSWORD" ]]; then
    error "Пароль администратора не может быть пустым"
fi

# Генерация SECRET_KEY
SECRET_KEY=$(openssl rand -hex 32)

log "Конфигурация:"
info "Сервер: $SERVER_IP"
info "Домен: $DOMAIN"
info "Email: $EMAIL"
info "Пароль БД: [скрыт]"
info "Пароль админа: [скрыт]"
info "SECRET_KEY: сгенерирован"

echo ""
read -p "Продолжить установку? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Установка отменена"
fi

# Функция создания пользователя
create_user() {
    log "Создание пользователя kododrive..."

    if id "kododrive" &>/dev/null; then
        warning "Пользователь kododrive уже существует, удаляем старого..."
        userdel -r kododrive 2>/dev/null || true
    fi

    useradd -m -s /bin/bash kododrive || error "Не удалось создать пользователя"
    usermod -aG sudo,www-data kododrive || error "Не удалось добавить пользователя в группы"

    # Создаем SSH директорию для пользователя
    mkdir -p /home/kododrive/.ssh
    chmod 700 /home/kododrive/.ssh
    chown -R kododrive:kododrive /home/kododrive

    log "Пользователь kododrive создан успешно"
}

# Функция обновления системы
update_system() {
    log "Обновление системы..."

    export DEBIAN_FRONTEND=noninteractive
    apt update -qq || error "Не удалось обновить список пакетов"
    apt upgrade -y -qq || error "Не удалось обновить систему"
    apt install -y -qq software-properties-common curl wget gnupg lsb-release || error "Не удалось установить базовые пакеты"

    log "Система обновлена успешно"
}

# Функция установки пакетов
install_packages() {
    log "Установка необходимых пакетов..."

    apt install -y -qq \
        python3 python3-pip python3-venv python3-dev build-essential \
        postgresql postgresql-contrib libpq-dev \
        nginx certbot python3-certbot-nginx \
        git htop nano vim unzip ufw fail2ban logrotate \
        || error "Ошибка при установке пакетов."

    python3 -m pip install --upgrade pip || error "Не удалось обновить pip"

    log "Все пакеты установлены успешно"
}

# Функция настройки PostgreSQL
setup_postgresql() {
    log "Настройка PostgreSQL..."

    systemctl enable --now postgresql || error "Не удалось запустить PostgreSQL."
    sleep 5
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS kododrive_db;" &>/dev/null
    sudo -u postgres psql -c "DROP USER IF EXISTS kododrive;" &>/dev/null
    sudo -u postgres psql -c "CREATE DATABASE kododrive_db;" || error "Не удалось создать базу данных."
    sudo -u postgres psql -c "CREATE USER kododrive WITH ENCRYPTED PASSWORD '$DB_PASSWORD';" || error "Не удалось создать пользователя БД."
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kododrive_db TO kododrive;" || error "Не удалось выдать права."
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U kododrive -d kododrive_db -c "SELECT 1" >/dev/null || error "Не удалось подключиться к базе данных."

    log "PostgreSQL настроен и протестирован"
}

# Функция создания структуры проекта
create_project_structure() {
    log "Создание структуры проекта..."

    PROJECT_DIR="/home/kododrive/portfolio"
    if [ -d "$PROJECT_DIR" ]; then rm -rf "$PROJECT_DIR"; fi
    sudo -u kododrive mkdir -p $PROJECT_DIR/{static/{css,js,img,uploads},templates/{admin,errors},logs,backups,scripts}

    log "Структура проекта создана"
}

# Функция создания файлов проекта
create_project_files() {
    log "Создание файлов проекта..."
    PROJECT_DIR="/home/kododrive/portfolio"

    # --- Python файлы ---
    tee $PROJECT_DIR/.env >/dev/null << EOF
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://kododrive:$DB_PASSWORD@localhost/kododrive_db
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
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- Модели БД ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    def set_password(self, password): self.password_hash = generate_password_hash(password)
    def check_password(self, password): return check_password_hash(self.password_hash, password)

class SiteSettings(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    site_title = db.Column(db.String(200), default='KodoDrive Portfolio')
    hero_title = db.Column(db.String(200), default='Привет, я KodoDrive')
    hero_subtitle = db.Column(db.String(200), default='Python Full Stack Developer')
    hero_description = db.Column(db.Text, default='Специализируюсь на создании Telegram-ботов')
    about_title = db.Column(db.String(200), default='Python Full Stack Developer')
    about_description = db.Column(db.Text, default='Разрабатываю Telegram-ботов и автоматизирую процессы')
    contact_email = db.Column(db.String(100), default='kododrive@example.com')
    contact_telegram = db.Column(db.String(100), default='@kodoDrive')
    contact_github = db.Column(db.String(100), default='github.com/svod011929')

class Service(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    icon = db.Column(db.String(50), default='fas fa-cogs')

class Portfolio(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    short_description = db.Column(db.String(255))
    technologies = db.Column(db.Text)
    github_url = db.Column(db.String(255))

class ContactMessage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    subject = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session: return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

# --- Публичные маршруты ---
@app.route('/')
def index():
    return render_template('index.html', s=SiteSettings.query.first(), services=Service.query.all(), portfolio=Portfolio.query.all())

# --- Маршруты Админ-панели ---
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form['username']).first()
        if user and user.check_password(request.form['password']):
            session['user_id'] = user.id
            return redirect(url_for('admin_dashboard'))
        flash('Неверные данные', 'error')
    return render_template('admin/login.html')

@app.route('/admin/logout')
def admin_logout():
    session.pop('user_id', None)
    return redirect(url_for('index'))

@app.route('/admin')
@login_required
def admin_dashboard():
    return render_template('admin/dashboard.html', projects_count=Portfolio.query.count(), services_count=Service.query.count(), messages_count=ContactMessage.query.filter_by(is_read=False).count())

@app.route('/admin/settings', methods=['GET', 'POST'])
@login_required
def admin_settings():
    s = SiteSettings.query.first()
    if request.method == 'POST':
        for key, value in request.form.items(): setattr(s, key, value)
        db.session.commit()
        flash('Настройки сохранены.', 'success')
        return redirect(url_for('admin_settings'))
    return render_template('admin/settings.html', s=s)

@app.route('/admin/services', methods=['GET', 'POST'])
@login_required
def admin_services():
    if request.method == 'POST':
        db.session.add(Service(title=request.form['title'], description=request.form['description'], icon=request.form['icon'])); db.session.commit()
        flash('Услуга добавлена.'); return redirect(url_for('admin_services'))
    return render_template('admin/services.html', services=Service.query.all())
@app.route('/admin/services/delete/<int:id>')
@login_required
def admin_service_delete(id): db.session.delete(Service.query.get_or_404(id)); db.session.commit(); return redirect(url_for('admin_services'))

@app.route('/admin/portfolio', methods=['GET', 'POST'])
@login_required
def admin_portfolio():
    if request.method == 'POST':
        db.session.add(Portfolio(title=request.form['title'], description=request.form['description'], short_description=request.form['short_description'], technologies=request.form['technologies'])); db.session.commit()
        flash('Проект добавлен.'); return redirect(url_for('admin_portfolio'))
    return render_template('admin/portfolio.html', projects=Portfolio.query.all())
@app.route('/admin/portfolio/edit/<int:id>', methods=['GET','POST'])
@login_required
def admin_portfolio_edit(id):
    p = Portfolio.query.get_or_404(id)
    if request.method == 'POST':
        p.title, p.description, p.short_description, p.technologies = request.form['title'], request.form['description'], request.form['short_description'], request.form['technologies']
        db.session.commit()
        flash('Проект обновлен.'); return redirect(url_for('admin_portfolio'))
    return render_template('admin/portfolio_form.html', p=p)
@app.route('/admin/portfolio/delete/<int:id>')
@login_required
def admin_portfolio_delete(id): db.session.delete(Portfolio.query.get_or_404(id)); db.session.commit(); return redirect(url_for('admin_portfolio'))

@app.route('/admin/messages')
@login_required
def admin_messages(): return render_template('admin/messages.html', messages=ContactMessage.query.order_by(ContactMessage.created_at.desc()).all())

@app.cli.command('init-db')
def init_db_command():
    if User.query.count() == 0:
        db.drop_all()
        db.create_all()
        admin = User(username=os.environ.get('ADMIN_USERNAME')); admin.set_password(os.environ.get('ADMIN_PASSWORD')); db.session.add(admin)
        db.session.add(SiteSettings())
        services_data = [Service(title='Разработка Telegram Ботов',description='Создание ботов любой сложности.'), Service(title='Веб-разработка на Flask',description='Создание легких и быстрых сайтов.')]
        portfolio_data = [Portfolio(title='Бот для E-commerce',description='Магазин в Telegram.',short_description='Магазин в Telegram.',technologies='Python, Aiogram'), Portfolio(title='CRM Система',description='Система управления клиентами.',short_description='Веб-приложение CRM',technologies='Python, Flask')]
        for s in services_data: db.session.add(s)
        for p in portfolio_data: db.session.add(p)
        db.session.commit()
        print("Database initialized.")
EOF

    # --- HTML шаблоны ---
    # Главная страница
    tee $PROJECT_DIR/templates/index.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><title>{{ s.site_title }}</title><link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}"><link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet"></head><body><header class="hero"><div class="container"><h1>{{ s.hero_title }}</h1><p>{{ s.hero_subtitle }}</p></div></header><main><section id="about" class="container"><h2>{{ s.about_title }}</h2><p>{{ s.about_description }}</p></section><section id="services" class="container"><h2>Услуги</h2><div class="grid">{% for service in services %}<article class="card"><h3><i class="{{ service.icon }}"></i> {{ service.title }}</h3><p>{{ service.description }}</p></article>{% endfor %}</div></section><section id="portfolio" class="container"><h2>Портфолио</h2><div class="grid">{% for project in portfolio %}<article class="card"><h3>{{ project.title }}</h3><p>{{ project.short_description }}</p><p><b>Технологии:</b> {{ project.technologies }}</p></article>{% endfor %}</div></section></main><footer><div class="container"><p>&copy; 2025 KodoDrive</p></div></footer></body></html>
EOF
    # Базовый шаблон админки
    tee $PROJECT_DIR/templates/admin/base.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><title>Админ-панель</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet"></head><body class="bg-light">
<div class="container-fluid"><div class="row"><nav class="col-md-2 d-none d-md-block bg-dark sidebar vh-100"><div class="sidebar-sticky pt-3"><ul class="nav flex-column">
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_dashboard') }}">Dashboard</a></li>
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_settings') }}">Настройки</a></li>
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_services') }}">Услуги</a></li>
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_portfolio') }}">Портфолио</a></li>
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_messages') }}">Сообщения</a></li>
<li class="nav-item"><a class="nav-link text-white" href="{{ url_for('admin_logout') }}">Выйти</a></li></ul></div></nav>
<main role="main" class="col-md-9 ms-sm-auto col-lg-10 px-4"><div class="pt-3">
{% with messages = get_flashed_messages(with_categories=true) %}{% if messages %}{% for category, message in messages %}<div class="alert alert-{{ 'success' if category == 'success' else 'danger' }}">{{ message }}</div>{% endfor %}{% endif %}{% endwith %}
{% block content %}{% endblock %}</div></main></div></div></body></html>
EOF
    # Шаблоны CRUD
    tee $PROJECT_DIR/templates/admin/dashboard.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h1>Dashboard</h1><p>Проектов: {{ projects_count }} | Услуг: {{ services_count }} | Новых сообщений: {{ messages_count }}</p>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/login.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<div class="d-flex vh-100 justify-content-center align-items-center"><form method="post" class="p-5 border rounded-3 bg-white"><h2>Вход</h2><div class="mb-3"><label>Логин</label><input type="text" name="username" class="form-control" required></div><div class="mb-3"><label>Пароль</label><input type="password" name="password" class="form-control" required></div><button type="submit" class="btn btn-primary">Войти</button></form></div>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/settings.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h1>Настройки сайта</h1><form method="post">{% for key, value in s.__dict__.items() if not key.startswith('_') and key != 'id' %}<div class="mb-3"><label class="form-label text-capitalize">{{ key.replace('_', ' ') }}</label><input type="text" name="{{ key }}" value="{{ value or '' }}" class="form-control"></div>{% endfor %}<button type="submit" class="btn btn-primary">Сохранить</button></form>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/services.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Управление Услугами</h2><form method="post" class="mb-4 p-4 border rounded"><h3>Добавить услугу</h3><div class="mb-3"><label>Название</label><input name="title" class="form-control" required></div><div class="mb-3"><label>Описание</label><textarea name="description" class="form-control" required></textarea></div><div class="mb-3"><label>Иконка FontAwesome</label><input name="icon" value="fas fa-cogs" class="form-control"></div><button type="submit" class="btn btn-success">Добавить</button></form><hr><h3>Список услуг</h3><table class="table"><thead><tr><th>Иконка</th><th>Название</th><th>Описание</th><th>Действие</th></tr></thead><tbody>{% for service in services %}<tr><td><i class="{{ service.icon }}"></i></td><td>{{ service.title }}</td><td>{{ service.description }}</td><td><a href="{{ url_for('admin_service_delete', id=service.id) }}" class="btn btn-sm btn-danger" onclick="return confirm('Удалить?')">Удалить</a></td></tr>{% endfor %}</tbody></table>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/portfolio.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Управление Портфолио</h2><form method="post" class="mb-4 p-4 border rounded"><h3>Добавить проект</h3><div class="mb-3"><label>Название</label><input name="title" required class="form-control"></div><div class="mb-3"><label>Краткое описание</label><input name="short_description" class="form-control"></div><div class="mb-3"><label>Полное описание</label><textarea name="description" required class="form-control"></textarea></div><div class="mb-3"><label>Технологии (через запятую)</label><input name="technologies" class="form-control"></div><div class="mb-3"><label>Ссылка на GitHub</label><input name="github_url" class="form-control"></div><button type="submit" class="btn btn-success">Добавить</button></form><hr><h3>Проекты</h3><table class="table"><thead><tr><th>Название</th><th>Описание</th><th>Технологии</th><th>Действия</th></tr></thead><tbody>{% for p in projects %}<tr><td>{{ p.title }}</td><td>{{ p.short_description }}</td><td>{{ p.technologies }}</td><td><a href="{{ url_for('admin_portfolio_edit', id=p.id) }}" class="btn btn-sm btn-secondary">Редактировать</a> <a href="{{ url_for('admin_portfolio_delete', id=p.id) }}" class="btn btn-sm btn-danger" onclick="return confirm('Удалить?')">Удалить</a></td></tr>{% endfor %}</tbody></table>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/portfolio_form.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Редактировать проект: {{ p.title }}</h2><form method="post"><div class="mb-3"><label>Название</label><input name="title" value="{{ p.title }}" required class="form-control"></div><div class="mb-3"><label>Краткое описание</label><input name="short_description" value="{{ p.short_description }}" class="form-control"></div><div class="mb-3"><label>Полное описание</label><textarea name="description" required class="form-control">{{ p.description }}</textarea></div><div class="mb-3"><label>Технологии</label><input name="technologies" value="{{ p.technologies or '' }}" class="form-control"></div><div class="mb-3"><label>Ссылка GitHub</label><input name="github_url" value="{{ p.github_url or '' }}" class="form-control"></div><button type="submit" class="btn btn-primary">Сохранить</button></form>{% endblock %}
EOF
    tee $PROJECT_DIR/templates/admin/messages.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Сообщения</h2><table class="table"><thead><tr><th>Дата</th><th>От кого</th><th>Тема</th><th>Прочитано</th><th>Действия</th></tr></thead><tbody>{% for m in messages %}<tr><td>{{ m.created_at.strftime('%Y-%m-%d %H:%M') }}</td><td>{{ m.name }} &lt;{{m.email}}&gt;</td><td>{{ m.subject }}</td><td><b>{{ 'Да' if m.is_read else 'Нет' }}</b></td><td><a href="{{ url_for('admin_message_delete', id=m.id) }}" class="btn btn-sm btn-danger" onclick="return confirm('Удалить?')">Удалить</a></td></tr>{% endfor %}</tbody></table>{% endblock %}
EOF

    # --- CSS & JS ---
    tee $PROJECT_DIR/static/css/style.css >/dev/null << 'EOF'
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background: #f0f2f5; color: #333; line-height: 1.6; } .container { max-width: 960px; margin: 2em auto; padding: 0 1em; } .hero { text-align: center; padding: 4em 1em; } .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5em; } .card { background: white; padding: 1.5em; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); } .footer { text-align: center; margin-top: 4em; padding: 2em 0; color: #777; }
EOF

    chown -R kododrive:kododrive "$PROJECT_DIR"
    log "Файлы проекта полностью перезаписаны."
}

# Функция настройки Flask приложения
setup_flask_app() {
    log "Настройка Flask приложения..."

    sudo -u kododrive bash -c "
        cd '/home/kododrive/portfolio' &&
        python3 -m venv venv &&
        source venv/bin/activate &&
        pip install --upgrade pip -qq &&
        pip install -r requirements.txt -qq &&
        echo 'Инициализация базы данных...' &&
        flask init-db
    " || error "Ошибка при настройке Flask."

    log "Flask приложение настроено."
}

# Функция создания systemd сервиса
create_systemd_service() {
    log "Создание systemd сервиса..."
    tee /etc/systemd/system/kododrive-portfolio.service >/dev/null <<EOF
[Unit]
Description=KodoDrive Portfolio Gunicorn Instance
After=network.target

[Service]
User=kododrive
Group=www-data
WorkingDirectory=/home/kododrive/portfolio
EnvironmentFile=/home/kododrive/portfolio/.env
ExecStart=/home/kododrive/portfolio/venv/bin/gunicorn --workers 3 --bind unix:portfolio.sock -m 007 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now kododrive-portfolio || error "Не удалось запустить сервис kododrive-portfolio."

    log "Systemd сервис запущен."
}

# Функция настройки Nginx и SSL
setup_nginx() {
    log "Настройка Nginx и SSL..."

    rm -f /etc/nginx/sites-enabled/default

    domain_config="/etc/nginx/sites-available/$DOMAIN"

    tee $domain_config >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/html;
    location /.well-known/acme-challenge/ { allow all; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF

    ln -sf $domain_config /etc/nginx/sites-enabled/
    nginx -t || error "Ошибка синтаксиса конфигурации Nginx."
    systemctl restart nginx || error "Не удалось перезапустить Nginx."

    certbot --nginx --agree-tos --no-eff-email --email "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN" || error "Не удалось получить SSL сертификат."

    tee $domain_config >/dev/null <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /static {
        alias /home/kododrive/portfolio/static;
    }
    location / {
        proxy_pass http://unix:/home/kododrive/portfolio/portfolio.sock;
        include proxy_params;
    }
}
EOF

    nginx -t || error "Ошибка финальной конфигурации Nginx."
    systemctl reload nginx

    log "Nginx и SSL настроены."
}

# Функция настройки безопасности
setup_security() {
    log "Настройка безопасности..."

    # Firewall
    info "Настройка правил Firewall..."
    ufw allow 22/tcp comment 'OpenSSH' || warning "Не удалось добавить правило для SSH"
    ufw allow 80/tcp comment 'HTTP' || warning "Не удалось добавить правило для HTTP"
    ufw allow 443/tcp comment 'HTTPS' || warning "Не удалось добавить правило для HTTPS"
    ufw --force enable || error "Не удалось включить firewall"
    info "Статус Firewall:"
    ufw status verbose

    # Настройка прав доступа
    chmod 755 /home/kododrive

    log "Безопасность настроена."
}

# Главная функция установки
main() {
    trap 'error "Установка прервана на строке $LINENO."' ERR

    create_user
    update_system
    install_packages
    setup_postgresql
    create_project_structure
    create_project_files
    setup_flask_app
    create_systemd_service
    setup_nginx
    setup_security

    log "Финальный перезапуск сервисов..."
    systemctl restart kododrive-portfolio
    systemctl restart nginx

    log "Выполнение финальных проверок..."
    if ! systemctl is-active --quiet kododrive-portfolio; then error "Сервис Flask не запустился."; fi
    if ! systemctl is-active --quiet nginx; then error "Сервис Nginx не запустился."; fi
    if ! curl -sfI https://$DOMAIN >/dev/null; then warning "Сайт недоступен, проверьте DNS записи."; fi

    # Вывод итоговой информации
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! (v3.2 STABLE) 🎉                   ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF

    echo ""
    log "🌐 Ваш сайт доступен по адресу: https://$DOMAIN"
    log "🔐 Админ панель: https://$DOMAIN/admin/login"
    log "👤 Логин администратора: admin"
    log "🔑 Пароль администратора: $ADMIN_PASSWORD"
    echo ""
    info "📋 Полезные команды:"
    info "   • Статус сервиса: sudo systemctl status kododrive-portfolio"
    info "   • Логи приложения: sudo journalctl -u kododrive-portfolio -f"
    info "   • Перезапуск: sudo systemctl restart kododrive-portfolio"

    log "✅ Все готово! Приятного использования."
}

# Запуск основной функции
main

exit 0
