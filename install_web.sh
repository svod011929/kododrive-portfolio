#!/bin/bash

# ==============================================================================
# KodoDrive Portfolio - Automatic Installation Script
# Версия: 3.1 (COMPLETE & FIXED)
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
║                     Версия 3.1 (FIXED)                       ║
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
    usermod -aG sudo,www-data kododrive || error "Не удалось добавить пользователя в группу sudo"

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

create_project_structure() {
    log "Создание структуры проекта..."
    PROJECT_DIR="/home/kododrive/portfolio"
    if [ -d "$PROJECT_DIR" ]; then rm -rf "$PROJECT_DIR"; fi
    sudo -u kododrive mkdir -p $PROJECT_DIR/{static/{css,js,img,uploads},templates/{admin,errors},logs,backups,scripts}
    log "Структура проекта создана"
}

create_project_files() {
    log "Создание файлов проекта..."
    PROJECT_DIR="/home/kododrive/portfolio"

    # .env
    tee $PROJECT_DIR/.env << EOF >/dev/null
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://kododrive:$DB_PASSWORD@localhost/kododrive_db
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF
    # requirements.txt
    tee $PROJECT_DIR/requirements.txt << 'EOF' >/dev/null
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Werkzeug==3.0.1
psycopg2-binary==2.9.7
gunicorn==21.2.0
python-dotenv==1.0.0
EOF
    # wsgi.py
    tee $PROJECT_DIR/wsgi.py << 'EOF' > /dev/null
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from app import app
if __name__ == "__main__":
    app.run()
EOF
    # app.py (ПОЛНАЯ ВЕРСИЯ)
    tee $PROJECT_DIR/app.py << 'EOF' >/dev/null
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
    hero_description = db.Column(db.Text, default='Специализируюсь на создании Telegram-ботов любой сложности и скриптов автоматизации.')
    about_title = db.Column(db.String(200), default='Python Full Stack Developer')
    about_description = db.Column(db.Text, default='Разрабатываю Telegram-ботов и автоматизирую бизнес-процессы с помощью Python.')
    contact_email = db.Column(db.String(100), default='kododrive@example.com')
    contact_telegram = db.Column(db.String(100), default='@kodoDrive')
    contact_github = db.Column(db.String(100), default='github.com/svod011929')
    contact_linkedin = db.Column(db.String(100))

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
    @property
    def tech_list(self): return [t.strip() for t in (self.technologies or '').split(',') if t.strip()]

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
    return render_template('index.html', settings=SiteSettings.query.first(), services=Service.query.all(), portfolio=Portfolio.query.all())

# --- Маршруты админ-панели ---
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form['username']).first()
        if user and user.check_password(request.form['password']):
            session['user_id'] = user.id
            return redirect(url_for('admin_dashboard'))
        flash('Неверные данные для входа.', 'error')
    return render_template('admin/login.html')

@app.route('/admin/logout')
def admin_logout():
    session.pop('user_id', None)
    return redirect(url_for('index'))

@app.route('/admin')
@login_required
def admin_dashboard():
    return render_template('admin/dashboard.html',
        projects_count=Portfolio.query.count(),
        services_count=Service.query.count(),
        messages_count=ContactMessage.query.filter_by(is_read=False).count())

@app.route('/admin/settings', methods=['GET', 'POST'])
@login_required
def admin_settings():
    settings = SiteSettings.query.first()
    if request.method == 'POST':
        for key, value in request.form.items(): setattr(settings, key, value)
        db.session.commit()
        flash('Настройки успешно сохранены!', 'success')
        return redirect(url_for('admin_settings'))
    return render_template('admin/settings.html', settings=settings)

# --- CRUD Услуги ---
@app.route('/admin/services', methods=['GET', 'POST'])
@login_required
def admin_services_crud():
    if request.method == 'POST':
        new_service = Service(title=request.form['title'], description=request.form['description'], icon=request.form['icon'])
        db.session.add(new_service)
        db.session.commit()
        flash('Услуга успешно добавлена!')
        return redirect(url_for('admin_services_crud'))
    return render_template('admin/services.html', services=Service.query.all())

@app.route('/admin/service/delete/<int:id>')
@login_required
def admin_service_delete(id):
    db.session.delete(Service.query.get_or_404(id))
    db.session.commit()
    return redirect(url_for('admin_services_crud'))

# --- CRUD Портфолио ---
@app.route('/admin/portfolio', methods=['GET', 'POST'])
@login_required
def admin_portfolio_crud():
    if request.method == 'POST':
        new_project=Portfolio(title=request.form['title'], description=request.form['description'], short_description=request.form['short_description'], technologies=request.form['technologies'], github_url=request.form['github_url'])
        db.session.add(new_project)
        db.session.commit()
        flash('Проект успешно добавлен!')
        return redirect(url_for('admin_portfolio_crud'))
    return render_template('admin/portfolio.html', projects=Portfolio.query.all())

@app.route('/admin/portfolio/edit/<int:id>', methods=['GET', 'POST'])
@login_required
def admin_portfolio_edit(id):
    project = Portfolio.query.get_or_404(id)
    if request.method == 'POST':
        project.title = request.form['title']
        project.description = request.form['description']
        project.short_description = request.form['short_description']
        project.technologies = request.form['technologies']
        project.github_url = request.form['github_url']
        db.session.commit()
        flash('Проект успешно обновлен!')
        return redirect(url_for('admin_portfolio_crud'))
    return render_template('admin/portfolio_form.html', project=project)

@app.route('/admin/portfolio/delete/<int:id>')
@login_required
def admin_portfolio_delete(id):
    db.session.delete(Portfolio.query.get_or_404(id))
    db.session.commit()
    flash('Проект успешно удален!')
    return redirect(url_for('admin_portfolio_crud'))

# --- CRUD Сообщения ---
@app.route('/admin/messages')
@login_required
def admin_messages():
    messages = ContactMessage.query.order_by(ContactMessage.created_at.desc()).all()
    return render_template('admin/messages.html', messages=messages)

@app.route('/admin/message/read/<int:id>')
@login_required
def admin_message_read(id):
    message = ContactMessage.query.get_or_404(id)
    message.is_read = True
    db.session.commit()
    return redirect(url_for('admin_messages'))

@app.route('/admin/message/delete/<int:id>')
@login_required
def admin_message_delete(id):
    db.session.delete(ContactMessage.query.get_or_404(id))
    db.session.commit()
    flash('Сообщение удалено.')
    return redirect(url_for('admin_messages'))

# --- Инициализация БД ---
def init_db():
    if User.query.count() == 0:
        print("Creating initial database data...")
        admin=User(username=os.environ.get('ADMIN_USERNAME'))
        admin.set_password(os.environ.get('ADMIN_PASSWORD'))
        db.session.add(admin)
        db.session.add(SiteSettings())
        services = [Service(title='Разработка Telegram Ботов', description='Создание многофункциональных ботов.'), Service(title='Автоматизация процессов', description='Оптимизация рутинных задач.')]
        projects = [Portfolio(title='Бот для E-commerce', description='Полнофункциональный бот для интернет-магазина.', short_description='Магазин в Telegram.', technologies='Python, Aiogram'), Portfolio(title='CRM система', description='Приложение для управления клиентами.', short_description='Веб-приложение CRM', technologies='Python, Flask')]
        for s in services: db.session.add(s)
        for p in projects: db.session.add(p)
        db.session.commit()
        print("Initial data created.")

with app.app_context():
    db.create_all()
    init_db()
EOF

    chown -R kododrive:kododrive "$PROJECT_DIR"
    log "Python файлы созданы успешно."
}

create_templates() {
    log "Создание HTML шаблонов..."
    PROJECT_DIR="/home/kododrive/portfolio"

    # --- Главные шаблоны ---
    tee $PROJECT_DIR/templates/index.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><title>{{ settings.site_title }}</title><link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}"></head><body><h1>Сайт находится в разработке</h1></body></html>
EOF

    # --- Шаблоны админ-панели (ПОЛНЫЕ ВЕРСИИ) ---
    tee $PROJECT_DIR/templates/admin/base.html >/dev/null << 'EOF'
<!DOCTYPE html><html lang="ru"><head><meta charset="UTF-8"><title>Админ-панель</title><style>body{font-family: Arial, sans-serif; margin: 2em;} nav a{margin-right: 1em; text-decoration: none;} table{width: 100%; border-collapse: collapse; margin-top: 1em;} td,th{border: 1px solid #ccc; padding: 8px; text-align: left;} form{background: #f4f4f4; padding: 1em; margin-top: 1em; border-radius: 5px;} form input, form textarea{width: 500px; padding: 8px; margin-bottom: 1em; display: block;} .alert-success{color:green;} .alert-error{color:red;}</style></head><body>
<nav><a href="{{ url_for('admin_dashboard') }}">Dashboard</a> | <a href="{{ url_for('admin_settings') }}">Настройки</a> | <a href="{{ url_for('admin_services_crud') }}">Услуги</a> | <a href="{{ url_for('admin_portfolio_crud') }}">Портфолио</a> | <a href="{{ url_for('admin_messages') }}">Сообщения</a> | <a href="{{ url_for('admin_logout') }}">Выйти</a></nav><hr>
{% with messages = get_flashed_messages(with_categories=true) %}{% if messages %}{% for category, message in messages %}<div class="alert-{{ category }}">{{ message }}</div>{% endfor %}{% endif %}{% endwith %}
{% block content %}{% endblock %}</body></html>
EOF

    tee $PROJECT_DIR/templates/admin/login.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Вход в админ-панель</h2><form method="post"><label>Логин:</label><input type="text" name="username" required><label>Пароль:</label><input type="password" name="password" required><button type="submit">Войти</button></form>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/dashboard.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Dashboard</h2><p>Всего проектов в портфолио: {{ projects_count }}</p><p>Всего услуг: {{ services_count }}</p><p>Новых сообщений: {{ messages_count }}</p>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/settings.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Настройки Сайта</h2><form method="post">
{% for key, value in settings.__dict__.items() if not key.startswith('_') and key != 'id' %}
<label><b>{{ key }}</b></label><input type="text" name="{{ key }}" value="{{ value or '' }}">
{% endfor %}
<button type="submit">Сохранить</button></form>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/services.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Управление Услугами</h2><form method="post"><h3>Добавить услугу</h3><label>Название:</label><input name="title" required><label>Описание:</label><textarea name="description" required></textarea><label>Иконка (FontAwesome):</label><input name="icon" value="fas fa-cogs"><button type="submit">Добавить</button></form><hr><h3>Список услуг</h3>
<table><thead><tr><th>Иконка</th><th>Название</th><th>Описание</th><th>Действие</th></tr></thead><tbody>
{% for s in services %}<tr><td><i class="{{ s.icon }}"></i> {{ s.icon }}</td><td>{{ s.title }}</td><td>{{ s.description }}</td><td><a href="{{ url_for('admin_service_delete', id=s.id) }}" onclick="return confirm('Вы уверены?')">Удалить</a></td></tr>{% endfor %}
</tbody></table>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/portfolio.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Управление Портфолио</h2><form method="post"><h3>Добавить проект</h3>
<label>Название:</label><input name="title" required><label>Краткое описание:</label><input name="short_description"><label>Полное описание:</label><textarea name="description" required></textarea><label>Технологии (через запятую):</label><input name="technologies"><label>Ссылка на GitHub:</label><input name="github_url"><button type="submit">Добавить</button></form><hr><h3>Проекты</h3>
<table><thead><tr><th>Название</th><th>Краткое описание</th><th>Технологии</th><th>Действия</th></tr></thead><tbody>
{% for p in projects %}<tr><td>{{ p.title }}</td><td>{{ p.short_description }}</td><td>{{ p.technologies }}</td><td><a href="{{ url_for('admin_portfolio_edit', id=p.id) }}">Редактировать</a> <a href="{{ url_for('admin_portfolio_delete', id=p.id) }}" onclick="return confirm('Вы уверены?')">Удалить</a></td></tr>{% endfor %}
</tbody></table>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/portfolio_form.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Редактировать проект: {{ project.title }}</h2><form method="post">
<label>Название:</label><input name="title" value="{{ project.title }}" required><label>Краткое описание:</label><input name="short_description" value="{{ project.short_description }}"><label>Полное описание:</label><textarea name="description" required>{{ project.description }}</textarea><label>Технологии:</label><input name="technologies" value="{{ project.technologies }}"><label>Ссылка на GitHub:</label><input name="github_url" value="{{ project.github_url }}"><button type="submit">Сохранить</button></form>{% endblock %}
EOF

    tee $PROJECT_DIR/templates/admin/messages.html >/dev/null << 'EOF'
{% extends 'admin/base.html' %}{% block content %}<h2>Сообщения</h2><table><thead><tr><th>Дата</th><th>От кого</th><th>Тема</th><th>Прочитано</th><th>Действие</th></tr></thead><tbody>
{% for m in messages %}<tr><td>{{ m.created_at.strftime('%Y-%m-%d %H:%M') }}</td><td>{{ m.name }} ({{ m.email }})</td><td>{{ m.subject }}</td><td><b>{{ 'Да' if m.is_read else 'Нет' }}</b></td><td>{% if not m.is_read %}<a href="{{ url_for('admin_message_read', id=m.id) }}">Отметить прочитанным</a> | {% endif %}<a href="{{ url_for('admin_message_delete', id=m.id) }}" onclick="return confirm('Уверены?')">Удалить</a></td></tr>{% endfor %}
</tbody></table>{% endblock %}
EOF

    chown -R kododrive:kododrive "$PROJECT_DIR/templates"
    log "HTML шаблоны созданы успешно."
}

create_static_files() {
    log "Создание статических файлов..."
    PROJECT_DIR="/home/kododrive/portfolio"

    tee $PROJECT_DIR/static/css/style.css >/dev/null << 'EOF'
body { background: #f0f2f5; color: #333; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; line-height: 1.6; }
EOF

    chown -R kododrive:kododrive "$PROJECT_DIR/static"
    log "Статические файлы созданы."
}

setup_flask_app() {
    log "Настройка Flask приложения..."

    PROJECT_DIR="/home/kododrive/portfolio"

    sudo -u kododrive bash -c "
        cd '$PROJECT_DIR' &&
        python3 -m venv venv &&
        source venv/bin/activate &&
        pip install --upgrade pip -q &&
        pip install -r requirements.txt -q
    " || error "Ошибка при настройке виртуального окружения Python."

    log "Flask приложение настроено."
}

create_systemd_service() {
    log "Создание systemd сервиса..."

    tee /etc/systemd/system/kododrive-portfolio.service >/dev/null << EOF
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

    log "Systemd сервис создан и запущен."
}

setup_nginx_and_ssl() {
    log "Настройка Nginx и SSL..."

    rm -f /etc/nginx/sites-enabled/default

    tee /etc/nginx/sites-available/$DOMAIN >/dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location / {
        return 301 https://\$host\$request_uri;
    }
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    nginx -t || error "Ошибка синтаксиса конфигурации Nginx."
    systemctl restart nginx || error "Не удалось перезапустить Nginx."

    certbot --nginx --agree-tos --no-eff-email --email $EMAIL -d $DOMAIN -d www.$DOMAIN || error "Не удалось получить SSL сертификат."

    tee /etc/nginx/sites-available/$DOMAIN >/dev/null << EOF
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
        include proxy_params;
        proxy_pass http://unix:/home/kododrive/portfolio/portfolio.sock;
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

    create_user
    update_system
    install_packages
    setup_postgresql
    create_project_structure
    create_project_files
    create_templates
    create_static_files
    setup_flask_app
    create_systemd_service
    setup_nginx_and_ssl

    # Финальные проверки
    log "Выполнение финальных проверок..."
    if ! systemctl is-active --quiet kododrive-portfolio; then error "Сервис Flask не запустился."; fi
    if ! systemctl is-active --quiet nginx; then error "Сервис Nginx не запустился."; fi
    if ! curl -sfI https://$DOMAIN >/dev/null; then warning "Сайт недоступен, проверьте DNS записи."; fi

    # Вывод итоговой информации
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! (v3.1 FIXED) 🎉                   ║
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
    echo ""
    log "✅ Все готово! Приятного использования."
}

# Запуск основной функции
main

exit 0
