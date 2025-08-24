#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
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

# Проверка что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
    error "Этот скрипт должен быть запущен от имени root. Используйте: sudo bash install_web.sh"
fi

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
║                        Версия 2.0 (Fixed)                   ║
╚══════════════════════════════════════════════════════════════╝

EOF

# Сбор информации от пользователя
log "Добро пожаловать в установщик KodoDrive Portfolio!"
echo ""

read -p "Введите IP адрес вашего сервера: " SERVER_IP
read -p "Введите домен (например: kododrive.ru): " DOMAIN
read -p "Введите email для SSL сертификата: " EMAIL
read -p "Введите пароль для базы данных: " -s DB_PASSWORD
echo ""
read -p "Введите пароль для администратора сайта: " -s ADMIN_PASSWORD
echo ""

# Генерация SECRET_KEY
SECRET_KEY=$(openssl rand -hex 32)

log "Конфигурация:"
info "Сервер: $SERVER_IP"
info "Домен: $DOMAIN"
info "Email: $EMAIL"
info "Пароль БД: [скрыт]"
info "SECRET_KEY: сгенерирован"

echo ""
read -p "Продолжить установку? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Установка отменена"
fi

# Функция проверки команд
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "Команда $1 не найдена"
    fi
}

# Функция создания пользователя
create_user() {
    log "Создание пользователя kododrive..."
    if id "kododrive" &>/dev/null; then
        warning "Пользователь kododrive уже существует"
    else
        useradd -m -s /bin/bash kododrive
        usermod -aG sudo kododrive
        log "Пользователь kododrive создан"
    fi
}

# Функция обновления системы
update_system() {
    log "Обновление системы..."
    apt update && apt upgrade -y || error "Не удалось обновить систему"
    apt install software-properties-common -y || error "Не удалось установить software-properties-common"
}

# Функция установки пакетов
install_packages() {
    log "Установка необходимых пакетов..."
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        postgresql \
        postgresql-contrib \
        nginx \
        certbot \
        python3-certbot-nginx \
        git \
        curl \
        ufw \
        htop \
        nano \
        wget \
        unzip || error "Не удалось установить пакеты"

    log "Все пакеты установлены успешно"
}

# Функция настройки PostgreSQL
setup_postgresql() {
    log "Настройка PostgreSQL..."
    systemctl start postgresql || error "Не удалось запустить PostgreSQL"
    systemctl enable postgresql || error "Не удалось включить автозапуск PostgreSQL"

    # Создание базы данных и пользователя
    sudo -u postgres psql << EOF || error "Не удалось настроить базу данных"
CREATE DATABASE kododrive_db;
CREATE USER kododrive WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE kododrive_db TO kododrive;
ALTER USER kododrive CREATEDB;
\q
EOF

    log "База данных настроена"
}

# Функция создания структуры проекта
create_project_structure() {
    log "Создание структуры проекта..."

    PROJECT_DIR="/home/kododrive/kododrive-portfolio"

    # Удаляем старую директорию если существует
    if [ -d "$PROJECT_DIR" ]; then
        warning "Старая директория проекта найдена, удаляем..."
        rm -rf "$PROJECT_DIR"
    fi

    mkdir -p $PROJECT_DIR/{static/{css,js,img,uploads},templates/admin,nginx,systemd,scripts,instance,migrations}

    chown -R kododrive:kododrive /home/kododrive/

    log "Структура каталогов создана"
}

# Функция создания Python файлов (исправленная версия)
create_python_files() {
    log "Создание Python файлов..."

    # app.py (исправленная версия)
    cat > /home/kododrive/kododrive-portfolio/app.py << 'EOF'
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from functools import wraps
import os
from datetime import datetime
import json

app = Flask(__name__)

# Конфигурация
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'postgresql://kododrive:password@localhost/kododrive_db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.path.join(app.root_path, 'static', 'uploads')

db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Создаем папку для загрузок
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Модели базы данных
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)
    is_admin = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class SiteSettings(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    hero_title = db.Column(db.String(200), default="Привет, я KodoDrive")
    hero_subtitle = db.Column(db.String(200), default="Python Full Stack Developer")
    hero_description = db.Column(db.Text, default="Специализируюсь на создании Telegram-ботов любой сложности и скриптов автоматизации.")
    about_title = db.Column(db.String(200), default="Python Full Stack Developer")
    about_description = db.Column(db.Text)
    contact_email = db.Column(db.String(100), default="kododrive@example.com")
    contact_telegram = db.Column(db.String(100), default="@kodoDrive")
    contact_github = db.Column(db.String(100), default="github.com/kododrive")

class Skill(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    percentage = db.Column(db.Integer, nullable=False)
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)

class Service(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    icon = db.Column(db.String(50), default="fas fa-cogs")
    features = db.Column(db.Text)
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)

class Portfolio(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    icon = db.Column(db.String(50), default="fas fa-code")
    technologies = db.Column(db.Text)
    project_url = db.Column(db.String(200))
    github_url = db.Column(db.String(200))
    image_url = db.Column(db.String(200))
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Stats(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    label = db.Column(db.String(100), nullable=False)
    value = db.Column(db.Integer, nullable=False)
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)

# Декоратор для проверки авторизации
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

# Основные маршруты сайта
@app.route('/')
def index():
    settings = SiteSettings.query.first()
    if not settings:
        settings = SiteSettings()
        db.session.add(settings)
        db.session.commit()

    skills = Skill.query.filter_by(is_active=True).order_by(Skill.order_index).all()
    services = Service.query.filter_by(is_active=True).order_by(Service.order_index).all()
    portfolio = Portfolio.query.filter_by(is_active=True).order_by(Portfolio.order_index).all()
    stats = Stats.query.filter_by(is_active=True).order_by(Stats.order_index).all()

    # Преобразуем JSON поля
    for service in services:
        if service.features:
            try:
                service.features_list = json.loads(service.features)
            except:
                service.features_list = []
        else:
            service.features_list = []

    for project in portfolio:
        if project.technologies:
            try:
                project.tech_list = json.loads(project.technologies)
            except:
                project.tech_list = []
        else:
            project.tech_list = []

    return render_template('index.html', 
                         settings=settings, 
                         skills=skills, 
                         services=services, 
                         portfolio=portfolio,
                         stats=stats)

# Админ панель - Авторизация
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        user = User.query.filter_by(username=username).first()

        if user and check_password_hash(user.password_hash, password):
            session['user_id'] = user.id
            return redirect(url_for('admin_dashboard'))
        else:
            flash('Неверное имя пользователя или пароль', 'error')

    return render_template('admin/login.html')

@app.route('/admin/logout')
def admin_logout():
    session.pop('user_id', None)
    return redirect(url_for('index'))

# Админ панель - Главная
@app.route('/admin')
@login_required
def admin_dashboard():
    stats_data = {
        'portfolio_count': Portfolio.query.filter_by(is_active=True).count(),
        'services_count': Service.query.filter_by(is_active=True).count(),
        'skills_count': Skill.query.filter_by(is_active=True).count(),
        'total_projects': Portfolio.query.count()
    }
    return render_template('admin/dashboard.html', stats=stats_data)

# Админ панель - Настройки сайта
@app.route('/admin/settings', methods=['GET', 'POST'])
@login_required
def admin_settings():
    settings = SiteSettings.query.first()
    if not settings:
        settings = SiteSettings()
        db.session.add(settings)
        db.session.commit()

    if request.method == 'POST':
        settings.hero_title = request.form['hero_title']
        settings.hero_subtitle = request.form['hero_subtitle']
        settings.hero_description = request.form['hero_description']
        settings.about_title = request.form['about_title']
        settings.about_description = request.form['about_description']
        settings.contact_email = request.form['contact_email']
        settings.contact_telegram = request.form['contact_telegram']
        settings.contact_github = request.form['contact_github']

        db.session.commit()
        flash('Настройки успешно сохранены!', 'success')
        return redirect(url_for('admin_settings'))

    return render_template('admin/settings.html', settings=settings)

# Портфолио маршруты
@app.route('/admin/portfolio')
@login_required
def admin_portfolio():
    portfolio = Portfolio.query.order_by(Portfolio.order_index).all()
    return render_template('admin/portfolio.html', portfolio=portfolio)

@app.route('/admin/portfolio/add', methods=['GET', 'POST'])
@login_required
def admin_portfolio_add():
    if request.method == 'POST':
        portfolio = Portfolio(
            title=request.form['title'],
            description=request.form['description'],
            icon=request.form['icon'],
            technologies=request.form['technologies'],
            project_url=request.form.get('project_url', ''),
            github_url=request.form.get('github_url', ''),
            image_url=request.form.get('image_url', ''),
            order_index=int(request.form.get('order_index', 0))
        )
        db.session.add(portfolio)
        db.session.commit()
        flash('Проект добавлен!', 'success')
        return redirect(url_for('admin_portfolio'))

    return render_template('admin/portfolio_form.html', portfolio=None)

@app.route('/admin/portfolio/edit/<int:id>', methods=['GET', 'POST'])
@login_required
def admin_portfolio_edit(id):
    portfolio = Portfolio.query.get_or_404(id)

    if request.method == 'POST':
        portfolio.title = request.form['title']
        portfolio.description = request.form['description']
        portfolio.icon = request.form['icon']
        portfolio.technologies = request.form['technologies']
        portfolio.project_url = request.form.get('project_url', '')
        portfolio.github_url = request.form.get('github_url', '')
        portfolio.image_url = request.form.get('image_url', '')
        portfolio.order_index = int(request.form.get('order_index', 0))
        portfolio.is_active = 'is_active' in request.form

        db.session.commit()
        flash('Проект обновлен!', 'success')
        return redirect(url_for('admin_portfolio'))

    return render_template('admin/portfolio_form.html', portfolio=portfolio)

@app.route('/admin/portfolio/delete/<int:id>')
@login_required
def admin_portfolio_delete(id):
    portfolio = Portfolio.query.get_or_404(id)
    db.session.delete(portfolio)
    db.session.commit()
    flash('Проект удален!', 'success')
    return redirect(url_for('admin_portfolio'))

def create_initial_data():
    """Создание начальных данных"""
    try:
        # Навыки
        skills = [
            Skill(name="Python", percentage=95, order_index=1),
            Skill(name="Telegram Bot API", percentage=90, order_index=2),
            Skill(name="Flask/Django", percentage=85, order_index=3),
            Skill(name="PostgreSQL/MySQL", percentage=80, order_index=4)
        ]

        # Услуги
        services = [
            Service(
                title="Telegram Боты",
                description="Создание ботов любой сложности: от простых информационных до многофункциональных с базами данных",
                icon="fas fa-robot",
                features='["Интерактивные меню", "Обработка медиафайлов", "Интеграция с API", "Платежные системы"]',
                order_index=1
            ),
            Service(
                title="Автоматизация",
                description="Скрипты для автоматизации рутинных задач и бизнес-процессов в Telegram",
                icon="fas fa-cogs",
                features='["Парсинг данных", "Массовые рассылки", "Мониторинг чатов", "Обработка заявок"]',
                order_index=2
            ),
            Service(
                title="API Интеграция",
                description="Подключение ваших ботов к внешним сервисам и системам управления",
                icon="fas fa-plug",
                features='["CRM системы", "Базы данных", "Облачные сервисы", "Веб-приложения"]',
                order_index=3
            )
        ]

        # Проекты
        portfolio = [
            Portfolio(
                title="E-commerce Бот",
                description="Полнофункциональный бот для интернет-магазина с каталогом товаров, корзиной и системой оплаты",
                icon="fas fa-shopping-cart",
                technologies='["Python", "aiogram", "PostgreSQL", "Stripe API"]',
                order_index=1
            ),
            Portfolio(
                title="Бот-планировщик",
                description="Система управления задачами и напоминаний с календарной интеграцией",
                icon="fas fa-calendar-alt",
                technologies='["Python", "python-telegram-bot", "SQLite", "Google Calendar API"]',
                order_index=2
            ),
            Portfolio(
                title="Аналитический Бот",
                description="Бот для сбора и анализа статистики чатов с генерацией отчетов",
                icon="fas fa-chart-line",
                technologies='["Python", "Telethon", "MongoDB", "Matplotlib"]',
                order_index=3
            )
        ]

        # Статистика
        stats = [
            Stats(label="Проектов завершено", value=50, order_index=1),
            Stats(label="Довольных клиентов", value=35, order_index=2),
            Stats(label="Года опыта", value=2, order_index=3)
        ]

        for item_list in [skills, services, portfolio, stats]:
            for item in item_list:
                db.session.add(item)

        db.session.commit()
        print("Начальные данные созданы успешно!")
    except Exception as e:
        print(f"Ошибка при создании начальных данных: {e}")
        db.session.rollback()

if __name__ == '__main__':
    with app.app_context():
        db.create_all()

        # Создание админа и начальных данных если их нет
        if User.query.count() == 0:
            admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
            admin = User(
                username='admin',
                password_hash=generate_password_hash(admin_password),
                is_admin=True
            )
            db.session.add(admin)

            create_initial_data()
            db.session.commit()
            print(f"Админ создан с паролем: {admin_password}")

    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

    # requirements.txt (обновленная версия)
    cat > /home/kododrive/kododrive-portfolio/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Flask-Migrate==4.0.5
Werkzeug==3.0.1
psycopg2-binary==2.9.7
gunicorn==21.2.0
python-dotenv==1.0.0
Jinja2==3.1.2
MarkupSafe==2.1.3
EOF

    # wsgi.py
    cat > /home/kododrive/kododrive-portfolio/wsgi.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

# Добавляем путь к проекту
sys.path.insert(0, '/home/kododrive/kododrive-portfolio')

from app import app

if __name__ == "__main__":
    app.run()
EOF

    # .env файл с правильными переменными
    cat > /home/kododrive/kododrive-portfolio/.env << EOF
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://kododrive:$DB_PASSWORD@localhost/kododrive_db
DOMAIN=$DOMAIN
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF

    chmod +x /home/kododrive/kododrive-portfolio/wsgi.py
    chown -R kododrive:kododrive /home/kododrive/kododrive-portfolio/
    log "Python файлы созданы"
}

# Функция создания статических файлов (ваши оригинальные CSS и JS)
create_static_files() {
    log "Создание статических файлов..."

    # Копируем полный CSS из исходного кода
    cat > /home/kododrive/kododrive-portfolio/static/css/style.css << 'EOF'
:root {
    --primary-color: #6366f1;
    --secondary-color: #8b5cf6;
    --accent-color: #06b6d4;
    --bg-color: #0f0f23;
    --bg-secondary: #1a1a2e;
    --text-color: #ffffff;
    --text-muted: #a1a1aa;
    --border-color: #374151;
    --gradient: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
    --shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Inter', sans-serif;
    background-color: var(--bg-color);
    color: var(--text-color);
    line-height: 1.6;
    overflow-x: hidden;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

/* Header */
.header {
    position: fixed;
    top: 0;
    width: 100%;
    background: rgba(15, 15, 35, 0.95);
    backdrop-filter: blur(10px);
    z-index: 1000;
    transition: all 0.3s ease;
}

.navbar {
    padding: 1rem 0;
}

.nav-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.nav-logo h1 {
    font-size: 1.8rem;
    font-weight: 700;
    background: var(--gradient);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.nav-menu {
    display: flex;
    list-style: none;
    gap: 2rem;
}

.nav-link {
    text-decoration: none;
    color: var(--text-color);
    font-weight: 500;
    transition: color 0.3s ease;
    position: relative;
}

.nav-link:hover {
    color: var(--primary-color);
}

.nav-link::after {
    content: '';
    position: absolute;
    bottom: -5px;
    left: 0;
    width: 0;
    height: 2px;
    background: var(--gradient);
    transition: width 0.3s ease;
}

.nav-link:hover::after {
    width: 100%;
}

.hamburger {
    display: none;
    flex-direction: column;
    cursor: pointer;
}

.bar {
    width: 25px;
    height: 3px;
    background: var(--text-color);
    margin: 3px 0;
    transition: 0.3s;
}

/* Hero Section */
.hero {
    min-height: 100vh;
    display: flex;
    align-items: center;
    padding: 80px 0;
    position: relative;
    overflow: hidden;
}

.hero::before {
    content: '';
    position: absolute;
    top: -50%;
    right: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(99, 102, 241, 0.1) 0%, transparent 70%);
    animation: float 20s infinite linear;
}

.hero-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
    position: relative;
    z-index: 2;
}

.hero-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4rem;
    align-items: center;
}

.hero-title {
    font-size: 3.5rem;
    font-weight: 700;
    margin-bottom: 1rem;
    line-height: 1.2;
}

.hero-subtitle {
    font-size: 1.5rem;
    color: var(--primary-color);
    margin-bottom: 1.5rem;
    font-weight: 600;
}

.hero-description {
    font-size: 1.1rem;
    color: var(--text-muted);
    margin-bottom: 2rem;
    max-width: 500px;
}

.hero-buttons {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

.btn {
    padding: 12px 30px;
    border: none;
    border-radius: 50px;
    text-decoration: none;
    font-weight: 600;
    transition: all 0.3s ease;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
}

.btn-primary {
    background: var(--gradient);
    color: white;
    box-shadow: var(--shadow);
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 15px 40px rgba(99, 102, 241, 0.4);
}

.btn-secondary {
    background: transparent;
    color: var(--text-color);
    border: 2px solid var(--primary-color);
}

.btn-secondary:hover {
    background: var(--primary-color);
    transform: translateY(-2px);
}

.profile-card {
    position: relative;
    width: 300px;
    height: 300px;
    margin: 0 auto;
    background: var(--bg-secondary);
    border-radius: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: var(--shadow);
}

.profile-avatar {
    width: 150px;
    height: 150px;
    background: var(--gradient);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 4rem;
    color: white;
}

.floating-icons {
    position: absolute;
    width: 100%;
    height: 100%;
}

.floating-icons i {
    position: absolute;
    font-size: 2rem;
    color: var(--primary-color);
    animation: float 3s infinite ease-in-out;
}

.floating-icons i:nth-child(1) {
    top: 20px;
    left: 20px;
    animation-delay: 0s;
}

.floating-icons i:nth-child(2) {
    top: 20px;
    right: 20px;
    animation-delay: 0.5s;
}

.floating-icons i:nth-child(3) {
    bottom: 20px;
    left: 20px;
    animation-delay: 1s;
}

.floating-icons i:nth-child(4) {
    bottom: 20px;
    right: 20px;
    animation-delay: 1.5s;
}

/* About Section */
.about {
    padding: 100px 0;
    background: var(--bg-secondary);
}

.section-title {
    text-align: center;
    font-size: 2.5rem;
    font-weight: 700;
    margin-bottom: 3rem;
    background: var(--gradient);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.about-content {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 4rem;
    align-items: center;
}

.about-text h3 {
    font-size: 1.8rem;
    margin-bottom: 1rem;
    color: var(--primary-color);
}

.about-text p {
    font-size: 1.1rem;
    color: var(--text-muted);
    margin-bottom: 2rem;
}

.skills {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.skill {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.skill-name {
    font-weight: 600;
    color: var(--text-color);
}

.skill-bar {
    height: 8px;
    background: var(--border-color);
    border-radius: 4px;
    overflow: hidden;
}

.skill-progress {
    height: 100%;
    background: var(--gradient);
    width: 0;
    transition: width 2s ease;
    border-radius: 4px;
}

.about-stats {
    display: flex;
    flex-direction: column;
    gap: 2rem;
}

.stat {
    text-align: center;
    padding: 2rem;
    background: var(--bg-color);
    border-radius: 15px;
    box-shadow: var(--shadow);
}

.stat-number {
    font-size: 3rem;
    font-weight: 700;
    color: var(--primary-color);
    margin-bottom: 0.5rem;
}

.stat p {
    color: var(--text-muted);
    font-weight: 500;
}

/* Services Section */
.services {
    padding: 100px 0;
}

.services-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
}

.service-card {
    background: var(--bg-secondary);
    padding: 2.5rem;
    border-radius: 20px;
    text-align: center;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    border: 1px solid var(--border-color);
}

.service-card:hover {
    transform: translateY(-10px);
    box-shadow: var(--shadow);
}

.service-icon {
    width: 80px;
    height: 80px;
    background: var(--gradient);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1.5rem;
    font-size: 2rem;
    color: white;
}

.service-card h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    color: var(--text-color);
}

.service-card p {
    color: var(--text-muted);
    margin-bottom: 1.5rem;
    line-height: 1.6;
}

.service-card ul {
    list-style: none;
    text-align: left;
}

.service-card li {
    color: var(--text-muted);
    margin-bottom: 0.5rem;
    position: relative;
    padding-left: 1.5rem;
}

.service-card li::before {
    content: '✓';
    position: absolute;
    left: 0;
    color: var(--accent-color);
    font-weight: bold;
}

/* Portfolio Section */
.portfolio {
    padding: 100px 0;
    background: var(--bg-secondary);
}

.portfolio-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
}

.portfolio-item {
    background: var(--bg-color);
    border-radius: 20px;
    overflow: hidden;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    border: 1px solid var(--border-color);
}

.portfolio-item:hover {
    transform: translateY(-5px);
    box-shadow: var(--shadow);
}

.portfolio-image {
    height: 200px;
    background: var(--gradient);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 4rem;
    color: white;
}

.portfolio-content {
    padding: 2rem;
}

.portfolio-content h3 {
    font-size: 1.3rem;
    margin-bottom: 1rem;
    color: var(--text-color);
}

.portfolio-content p {
    color: var(--text-muted);
    margin-bottom: 1.5rem;
    line-height: 1.6;
}

.portfolio-tech {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
}

.portfolio-tech span {
    background: var(--primary-color);
    color: white;
    padding: 0.3rem 0.8rem;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: 500;
}

.portfolio-link {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 600;
    transition: color 0.3s ease;
}

.portfolio-link:hover {
    color: var(--accent-color);
}

/* Contact Section */
.contact {
    padding: 100px 0;
}

.contact-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4rem;
    align-items: start;
}

.contact-info h3 {
    font-size: 1.8rem;
    margin-bottom: 1rem;
    color: var(--text-color);
}

.contact-info p {
    color: var(--text-muted);
    margin-bottom: 2rem;
    font-size: 1.1rem;
}

.contact-details {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.contact-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    color: var(--text-muted);
}

.contact-item i {
    width: 20px;
    color: var(--primary-color);
    font-size: 1.2rem;
}

.contact-form {
    background: var(--bg-secondary);
    padding: 2.5rem;
    border-radius: 20px;
    border: 1px solid var(--border-color);
}

.form-group {
    margin-bottom: 1.5rem;
}

.form-group input,
.form-group textarea {
    width: 100%;
    padding: 1rem;
    border: 1px solid var(--border-color);
    border-radius: 10px;
    background: var(--bg-color);
    color: var(--text-color);
    font-family: inherit;
    transition: border-color 0.3s ease;
}

.form-group input:focus,
.form-group textarea:focus {
    outline: none;
    border-color: var(--primary-color);
}

.form-group textarea {
    resize: vertical;
    min-height: 120px;
}

/* Footer */
.footer {
    background: var(--bg-secondary);
    padding: 2rem 0;
    border-top: 1px solid var(--border-color);
}

.footer-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.footer-text p {
    color: var(--text-muted);
}

.footer-social {
    display: flex;
    gap: 1rem;
}

.social-link {
    width: 40px;
    height: 40px;
    background: var(--bg-color);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-color);
    text-decoration: none;
    transition: all 0.3s ease;
}

.social-link:hover {
    background: var(--primary-color);
    transform: translateY(-2px);
}

/* Animations */
@keyframes float {
    0%, 100% {
        transform: translateY(0px);
    }
    50% {
        transform: translateY(-20px);
    }
}

@keyframes fadeInUp {
    from {
        opacity: 0;
        transform: translateY(30px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.fade-in-up {
    animation: fadeInUp 0.8s ease forwards;
}

/* Responsive Design */
@media (max-width: 768px) {
    .hamburger {
        display: flex;
    }

    .nav-menu {
        position: fixed;
        left: -100%;
        top: 70px;
        flex-direction: column;
        background-color: var(--bg-secondary);
        width: 100%;
        text-align: center;
        transition: 0.3s;
        box-shadow: var(--shadow);
        padding: 2rem 0;
    }

    .nav-menu.active {
        left: 0;
    }

    .hero-content {
        grid-template-columns: 1fr;
        text-align: center;
        gap: 2rem;
    }

    .hero-title {
        font-size: 2.5rem;
    }

    .about-content {
        grid-template-columns: 1fr;
        gap: 2rem;
    }

    .contact-content {
        grid-template-columns: 1fr;
        gap: 2rem;
    }

    .services-grid {
        grid-template-columns: 1fr;
    }

    .portfolio-grid {
        grid-template-columns: 1fr;
    }

    .footer-content {
        flex-direction: column;
        gap: 1rem;
        text-align: center;
    }
}

@media (max-width: 480px) {
    .container {
        padding: 0 15px;
    }

    .hero-title {
        font-size: 2rem;
    }

    .section-title {
        font-size: 2rem;
    }

    .profile-card {
        width: 250px;
        height: 250px;
    }

    .profile-avatar {
        width: 120px;
        height: 120px;
        font-size: 3rem;
    }
}

/* Typing Animation */
.typing-text::after {
    content: '|';
    color: var(--primary-color);
    animation: blink 1s infinite;
}

@keyframes blink {
    0%, 50% {
        opacity: 1;
    }
    51%, 100% {
        opacity: 0;
    }
}
EOF

    # Копируем полный JavaScript из исходного кода
    cat > /home/kododrive/kododrive-portfolio/static/js/script.js << 'EOF'
// Mobile Navigation
const hamburger = document.querySelector('.hamburger');
const navMenu = document.querySelector('.nav-menu');

hamburger.addEventListener('click', () => {
    hamburger.classList.toggle('active');
    navMenu.classList.toggle('active');
});

// Close mobile menu when clicking on a link
document.querySelectorAll('.nav-link').forEach(n => n.addEventListener('click', () => {
    hamburger.classList.remove('active');
    navMenu.classList.remove('active');
}));

// Smooth Scrolling
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        const offsetTop = target.offsetTop - 80;

        window.scrollTo({
            top: offsetTop,
            behavior: 'smooth'
        });
    });
});

// Header Scroll Effect
window.addEventListener('scroll', () => {
    const header = document.querySelector('.header');
    if (window.scrollY > 100) {
        header.style.background = 'rgba(15, 15, 35, 0.98)';
        header.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.3)';
    } else {
        header.style.background = 'rgba(15, 15, 35, 0.95)';
        header.style.boxShadow = 'none';
    }
});

// Typing Animation
const typingText = document.querySelector('.typing-text');
const text = 'Привет, я KodoDrive';
let i = 0;

function typeWriter() {
    if (i < text.length) {
        typingText.innerHTML = text.slice(0, i + 1);
        i++;
        setTimeout(typeWriter, 100);
    }
}

// Start typing animation when page loads
window.addEventListener('load', () => {
    typingText.innerHTML = '';
    typeWriter();
});

// Animated Counters
function animateCounters() {
    const counters = document.querySelectorAll('.stat-number');

    counters.forEach(counter => {
        const target = parseInt(counter.getAttribute('data-target'));
        let current = 0;
        const increment = target / 200;

        const updateCounter = () => {
            if (current < target) {
                current += increment;
                counter.textContent = Math.ceil(current);
                setTimeout(updateCounter, 10);
            } else {
                counter.textContent = target;
            }
        };

        updateCounter();
    });
}

// Skill Bars Animation
function animateSkillBars() {
    const skillBars = document.querySelectorAll('.skill-progress');

    skillBars.forEach(bar => {
        const width = bar.getAttribute('data-width');
        bar.style.width = width;
    });
}

// Intersection Observer for Animations
const observerOptions = {
    threshold: 0.3,
    rootMargin: '0px 0px -100px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('fade-in-up');

            // Trigger specific animations
            if (entry.target.classList.contains('about')) {
                setTimeout(animateCounters, 500);
                setTimeout(animateSkillBars, 800);
            }
        }
    });
}, observerOptions);

// Observe sections for animations
document.querySelectorAll('section').forEach(section => {
    observer.observe(section);
});

// Portfolio Filter (если понадобится в будущем)
function filterPortfolio(category) {
    const items = document.querySelectorAll('.portfolio-item');

    items.forEach(item => {
        if (category === 'all' || item.dataset.category === category) {
            item.style.display = 'block';
            setTimeout(() => {
                item.style.opacity = '1';
                item.style.transform = 'scale(1)';
            }, 100);
        } else {
            item.style.opacity = '0';
            item.style.transform = 'scale(0.8)';
            setTimeout(() => {
                item.style.display = 'none';
            }, 300);
        }
    });
}

// Contact Form
const contactForm = document.getElementById('contactForm');

contactForm.addEventListener('submit', function(e) {
    e.preventDefault();

    // Получаем данные формы
    const formData = new FormData(contactForm);
    const name = formData.get('name');
    const email = formData.get('email');
    const subject = formData.get('subject');
    const message = formData.get('message');

    // Простая валидация
    if (!name || !email || !subject || !message) {
        showNotification('Пожалуйста, заполните все поля', 'error');
        return;
    }

    // Имитация отправки
    showNotification('Отправка сообщения...', 'info');

    setTimeout(() => {
        showNotification('Сообщение отправлено! Я свяжусь с вами в ближайшее время.', 'success');
        contactForm.reset();
    }, 2000);
});

// Notification System
function showNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;

    // Стили для уведомлений
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 10px;
        color: white;
        font-weight: 500;
        z-index: 10000;
        opacity: 0;
        transform: translateX(100%);
        transition: all 0.3s ease;
        max-width: 300px;
    `;

    // Цвета по типу
    switch(type) {
        case 'success':
            notification.style.background = '#10b981';
            break;
        case 'error':
            notification.style.background = '#ef4444';
            break;
        case 'info':
            notification.style.background = '#3b82f6';
            break;
        default:
            notification.style.background = '#6b7280';
    }

    document.body.appendChild(notification);

    // Анимация появления
    setTimeout(() => {
        notification.style.opacity = '1';
        notification.style.transform = 'translateX(0)';
    }, 100);

    // Удаление через 5 секунд
    setTimeout(() => {
        notification.style.opacity = '0';
        notification.style.transform = 'translateX(100%)';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 5000);
}

// Parallax Effect
window.addEventListener('scroll', () => {
    const scrolled = window.pageYOffset;
    const parallax = document.querySelectorAll('.hero::before');

    parallax.forEach(element => {
        const speed = 0.5;
        element.style.transform = `translateY(${scrolled * speed}px)`;
    });
});

// Lazy Loading для изображений (если будут добавлены)
const lazyImages = document.querySelectorAll('img[data-src]');
const imageObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const img = entry.target;
            img.src = img.dataset.src;
            img.classList.remove('lazy');
            imageObserver.unobserve(img);
        }
    });
});

lazyImages.forEach(img => imageObserver.observe(img));

// Theme Switcher (опционально)
function toggleTheme() {
    const root = document.documentElement;
    const currentTheme = root.style.getPropertyValue('--bg-color');

    if (currentTheme === '#0f0f23') {
        // Переключение на светлую тему
        root.style.setProperty('--bg-color', '#ffffff');
        root.style.setProperty('--bg-secondary', '#f8fafc');
        root.style.setProperty('--text-color', '#1f2937');
        root.style.setProperty('--text-muted', '#6b7280');
    } else {
        // Возврат к темной теме
        root.style.setProperty('--bg-color', '#0f0f23');
        root.style.setProperty('--bg-secondary', '#1a1a2e');
        root.style.setProperty('--text-color', '#ffffff');
        root.style.setProperty('--text-muted', '#a1a1aa');
    }
}

// Performance optimization
window.addEventListener('load', () => {
    // Preload critical resources
    const criticalResources = [
        'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css',
        'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap'
    ];

    criticalResources.forEach(resource => {
        const link = document.createElement('link');
        link.rel = 'prefetch';
        link.href = resource;
        document.head.appendChild(link);
    });
});

// Service Worker для кеширования (опционально)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}
EOF

    chown -R kododrive:kododrive /home/kododrive/kododrive-portfolio/static/
    log "Статические файлы созданы"
}

# Исправленная функция создания шаблонов
create_templates() {
    log "Создание HTML шаблонов..."

    # Базовый шаблон
    cat > /home/kododrive/kododrive-portfolio/templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}KodoDrive - Python Developer{% endblock %}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    {% block extra_head %}{% endblock %}
</head>
<body>
    {% block content %}{% endblock %}
    <script src="{{ url_for('static', filename='js/script.js') }}"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
EOF

    # templates/index.html (исправленная версия с правильными путями)
    cat > /home/kododrive/kododrive-portfolio/templates/index.html << 'EOF'
{% extends "base.html" %}

{% block title %}{{ settings.hero_title }} - {{ settings.hero_subtitle }}{% endblock %}

{% block content %}
    <!-- Header -->
    <header class="header">
        <nav class="navbar">
            <div class="nav-container">
                <div class="nav-logo">
                    <h1>KodoDrive</h1>
                </div>
                <ul class="nav-menu">
                    <li class="nav-item">
                        <a href="#home" class="nav-link">Главная</a>
                    </li>
                    <li class="nav-item">
                        <a href="#about" class="nav-link">О себе</a>
                    </li>
                    <li class="nav-item">
                        <a href="#services" class="nav-link">Услуги</a>
                    </li>
                    <li class="nav-item">
                        <a href="#portfolio" class="nav-link">Портфолио</a>
                    </li>
                    <li class="nav-item">
                        <a href="#contact" class="nav-link">Контакты</a>
                    </li>
                </ul>
                <div class="hamburger">
                    <span class="bar"></span>
                    <span class="bar"></span>
                    <span class="bar"></span>
                </div>
            </div>
        </nav>
    </header>

    <!-- Hero Section -->
    <section id="home" class="hero">
        <div class="hero-container">
            <div class="hero-content">
                <div class="hero-text">
                    <h1 class="hero-title">
                        <span class="typing-text">{{ settings.hero_title }}</span>
                    </h1>
                    <h2 class="hero-subtitle">{{ settings.hero_subtitle }}</h2>
                    <p class="hero-description">{{ settings.hero_description }}</p>
                    <div class="hero-buttons">
                        <a href="#portfolio" class="btn btn-primary">Мои проекты</a>
                        <a href="#contact" class="btn btn-secondary">Связаться</a>
                    </div>
                </div>
                <div class="hero-image">
                    <div class="profile-card">
                        <div class="profile-avatar">
                            <i class="fas fa-code"></i>
                        </div>
                        <div class="floating-icons">
                            <i class="fab fa-python"></i>
                            <i class="fab fa-telegram"></i>
                            <i class="fas fa-robot"></i>
                            <i class="fas fa-database"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- About Section -->
    <section id="about" class="about">
        <div class="container">
            <h2 class="section-title">О себе</h2>
            <div class="about-content">
                <div class="about-text">
                    <h3>{{ settings.about_title }}</h3>
                    <p>{{ settings.about_description or "Разрабатываю Telegram-ботов и автоматизирую бизнес-процессы с помощью Python. Имею опыт создания как простых информационных ботов, так и сложных систем с интеграцией баз данных, платежных систем и внешних API." }}</p>
                    <div class="skills">
                        {% for skill in skills %}
                        <div class="skill">
                            <span class="skill-name">{{ skill.name }}</span>
                            <div class="skill-bar">
                                <div class="skill-progress" data-width="{{ skill.percentage }}%"></div>
                            </div>
                        </div>
                        {% endfor %}
                    </div>
                </div>
                <div class="about-stats">
                    {% for stat in stats %}
                    <div class="stat">
                        <h3 class="stat-number" data-target="{{ stat.value }}">0</h3>
                        <p>{{ stat.label }}</p>
                    </div>
                    {% endfor %}
                </div>
            </div>
        </div>
    </section>

    <!-- Services Section -->
    <section id="services" class="services">
        <div class="container">
            <h2 class="section-title">Услуги</h2>
            <div class="services-grid">
                {% for service in services %}
                <div class="service-card">
                    <div class="service-icon">
                        <i class="{{ service.icon }}"></i>
                    </div>
                    <h3>{{ service.title }}</h3>
                    <p>{{ service.description }}</p>
                    {% if service.features_list %}
                    <ul>
                        {% for feature in service.features_list %}
                        <li>{{ feature }}</li>
                        {% endfor %}
                    </ul>
                    {% endif %}
                </div>
                {% endfor %}
            </div>
        </div>
    </section>

    <!-- Portfolio Section -->
    <section id="portfolio" class="portfolio">
        <div class="container">
            <h2 class="section-title">Портфолио</h2>
            <div class="portfolio-grid">
                {% for project in portfolio %}
                <div class="portfolio-item">
                    <div class="portfolio-image">
                        <i class="{{ project.icon }}"></i>
                    </div>
                    <div class="portfolio-content">
                        <h3>{{ project.title }}</h3>
                        <p>{{ project.description }}</p>
                        {% if project.tech_list %}
                        <div class="portfolio-tech">
                            {% for tech in project.tech_list %}
                            <span>{{ tech }}</span>
                            {% endfor %}
                        </div>
                        {% endif %}
                        {% if project.project_url %}
                        <a href="{{ project.project_url }}" class="portfolio-link" target="_blank">Подробнее</a>
                        {% endif %}
                    </div>
                </div>
                {% endfor %}
            </div>
        </div>
    </section>

    <!-- Contact Section -->
    <section id="contact" class="contact">
        <div class="container">
            <h2 class="section-title">Связаться со мной</h2>
            <div class="contact-content">
                <div class="contact-info">
                    <h3>Готов обсудить ваш проект</h3>
                    <p>Напишите мне о вашей идее, и я помогу воплотить её в жизнь с помощью Telegram-ботов</p>
                    <div class="contact-details">
                        <div class="contact-item">
                            <i class="fab fa-telegram"></i>
                            <span>{{ settings.contact_telegram }}</span>
                        </div>
                        <div class="contact-item">
                            <i class="fas fa-envelope"></i>
                            <span>{{ settings.contact_email }}</span>
                        </div>
                        <div class="contact-item">
                            <i class="fab fa-github"></i>
                            <span>{{ settings.contact_github }}</span>
                        </div>
                    </div>
                </div>
                <div class="contact-form">
                    <form id="contactForm">
                        <div class="form-group">
                            <input type="text" id="name" name="name" placeholder="Ваше имя" required>
                        </div>
                        <div class="form-group">
                            <input type="email" id="email" name="email" placeholder="Email" required>
                        </div>
                        <div class="form-group">
                            <input type="text" id="subject" name="subject" placeholder="Тема" required>
                        </div>
                        <div class="form-group">
                            <textarea id="message" name="message" rows="5" placeholder="Опишите ваш проект" required></textarea>
                        </div>
                        <button type="submit" class="btn btn-primary">Отправить сообщение</button>
                    </form>
                </div>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="footer">
        <div class="container">
            <div class="footer-content">
                <div class="footer-text">
                    <p>&copy; 2024 KodoDrive. Все права защищены.</p>
                </div>
                <div class="footer-social">
                    <a href="#" class="social-link"><i class="fab fa-telegram"></i></a>
                    <a href="#" class="social-link"><i class="fab fa-github"></i></a>
                    <a href="#" class="social-link"><i class="fab fa-linkedin"></i></a>
                </div>
            </div>
        </div>
    </footer>
{% endblock %}
EOF

    # Создание админ шаблонов (остальные админ шаблоны остаются без изменений)
    create_admin_templates

    chown -R kododrive:kododrive /home/kododrive/kododrive-portfolio/templates/
    log "HTML шаблоны созданы"
}

# Исправленная функция создания админ шаблонов (без изменений, но с проверкой ошибок)
create_admin_templates() {
    # templates/admin/layout.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/layout.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Админ панель - KodoDrive{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body { background: #f8f9fa; font-family: 'Inter', sans-serif; }
        .sidebar { min-height: 100vh; background: #2c3e50; }
        .sidebar .nav-link { color: #bdc3c7; padding: 12px 20px; border-radius: 8px; margin: 5px 15px; }
        .sidebar .nav-link:hover, .sidebar .nav-link.active { background: #3498db; color: white; }
        .card { border: none; border-radius: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <nav class="col-md-3 col-lg-2 d-md-block sidebar collapse">
                <div class="position-sticky pt-3">
                    <div class="text-center mb-4">
                        <h4 class="text-white">KodoDrive</h4>
                        <small class="text-muted">Admin Panel</small>
                    </div>
                    <ul class="nav flex-column">
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('admin_dashboard') }}">
                                <i class="fas fa-tachometer-alt me-2"></i>Dashboard
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('admin_settings') }}">
                                <i class="fas fa-cog me-2"></i>Настройки сайта
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('admin_portfolio') }}">
                                <i class="fas fa-briefcase me-2"></i>Портфолио
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('index') }}" target="_blank">
                                <i class="fas fa-external-link-alt me-2"></i>Посмотреть сайт
                            </a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('admin_logout') }}">
                                <i class="fas fa-sign-out-alt me-2"></i>Выйти
                            </a>
                        </li>
                    </ul>
                </div>
            </nav>
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <h1 class="h2 pt-3 pb-2 mb-3">{% block page_title %}Dashboard{% endblock %}</h1>
                {% with messages = get_flashed_messages(with_categories=true) %}
                    {% if messages %}
                        {% for category, message in messages %}
                            <div class="alert alert-{% if category == 'error' %}danger{% else %}{{ category }}{% endif %} alert-dismissible fade show">
                                {{ message }}
                                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                            </div>
                        {% endfor %}
                    {% endif %}
                {% endwith %}
                {% block content %}{% endblock %}
            </main>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF

    # templates/admin/login.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/login.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Вход в админ панель - KodoDrive</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            min-height: 100vh; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
        }
        .login-container { 
            background: white; 
            border-radius: 20px; 
            padding: 3rem; 
            width: 100%; 
            max-width: 400px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="text-center mb-4">
            <h2><i class="fas fa-code me-2"></i>KodoDrive</h2>
            <p class="text-muted">Админ панель</p>
        </div>
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{% if category == 'error' %}danger{% else %}{{ category }}{% endif %}">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}
        <form method="POST">
            <div class="mb-3">
                <input type="text" name="username" class="form-control" placeholder="Имя пользователя" required>
            </div>
            <div class="mb-4">
                <input type="password" name="password" class="form-control" placeholder="Пароль" required>
            </div>
            <button type="submit" class="btn btn-primary w-100">Войти</button>
        </form>
    </div>
</body>
</html>
EOF

    # Остальные админ шаблоны (dashboard, settings, portfolio, portfolio_form) остаются теми же...
    # Добавим их для полноты:

    # templates/admin/dashboard.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/dashboard.html << 'EOF'
{% extends "admin/layout.html" %}
{% block content %}
<div class="row">
    <div class="col-md-3 mb-4">
        <div class="card">
            <div class="card-body text-center">
                <h5>Проектов</h5>
                <h2 class="text-primary">{{ stats.portfolio_count }}</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-4">
        <div class="card">
            <div class="card-body text-center">
                <h5>Услуг</h5>
                <h2 class="text-success">{{ stats.services_count }}</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-4">
        <div class="card">
            <div class="card-body text-center">
                <h5>Навыков</h5>
                <h2 class="text-info">{{ stats.skills_count }}</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-4">
        <div class="card">
            <div class="card-body text-center">
                <h5>Всего</h5>
                <h2 class="text-warning">{{ stats.total_projects }}</h2>
            </div>
        </div>
    </div>
</div>
<div class="card">
    <div class="card-body">
        <h5>Быстрые действия</h5>
        <a href="{{ url_for('admin_portfolio_add') }}" class="btn btn-primary me-2">Добавить проект</a>
        <a href="{{ url_for('admin_settings') }}" class="btn btn-secondary">Настройки</a>
    </div>
</div>
{% endblock %}
EOF

    # templates/admin/settings.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/settings.html << 'EOF'
{% extends "admin/layout.html" %}
{% block page_title %}Настройки сайта{% endblock %}
{% block content %}
<div class="card">
    <div class="card-body">
        <form method="POST">
            <div class="mb-3">
                <label class="form-label">Заголовок Hero</label>
                <input type="text" name="hero_title" class="form-control" value="{{ settings.hero_title }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Подзаголовок Hero</label>
                <input type="text" name="hero_subtitle" class="form-control" value="{{ settings.hero_subtitle }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Описание Hero</label>
                <textarea name="hero_description" class="form-control" rows="3">{{ settings.hero_description }}</textarea>
            </div>
            <div class="mb-3">
                <label class="form-label">Заголовок "О себе"</label>
                <input type="text" name="about_title" class="form-control" value="{{ settings.about_title }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Описание "О себе"</label>
                <textarea name="about_description" class="form-control" rows="4">{{ settings.about_description }}</textarea>
            </div>
            <div class="mb-3">
                <label class="form-label">Email</label>
                <input type="email" name="contact_email" class="form-control" value="{{ settings.contact_email }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Telegram</label>
                <input type="text" name="contact_telegram" class="form-control" value="{{ settings.contact_telegram }}">
            </div>
            <div class="mb-3">
                <label class="form-label">GitHub</label>
                <input type="text" name="contact_github" class="form-control" value="{{ settings.contact_github }}">
            </div>
            <button type="submit" class="btn btn-primary">Сохранить</button>
        </form>
    </div>
</div>
{% endblock %}
EOF

    # templates/admin/portfolio.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/portfolio.html << 'EOF'
{% extends "admin/layout.html" %}
{% block page_title %}Портфолио{% endblock %}
{% block content %}
<div class="d-flex justify-content-between mb-4">
    <h2>Портфолио</h2>
    <a href="{{ url_for('admin_portfolio_add') }}" class="btn btn-primary">Добавить проект</a>
</div>
<div class="card">
    <div class="card-body">
        {% if portfolio %}
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Название</th>
                            <th>Описание</th>
                            <th>Активен</th>
                            <th>Действия</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for project in portfolio %}
                        <tr>
                            <td><strong>{{ project.title }}</strong></td>
                            <td>{{ project.description[:100] }}...</td>
                            <td>
                                {% if project.is_active %}
                                    <span class="badge bg-success">Да</span>
                                {% else %}
                                    <span class="badge bg-danger">Нет</span>
                                {% endif %}
                            </td>
                            <td>
                                <a href="{{ url_for('admin_portfolio_edit', id=project.id) }}" class="btn btn-sm btn-outline-primary me-1">Редактировать</a>
                                <a href="{{ url_for('admin_portfolio_delete', id=project.id) }}" class="btn btn-sm btn-outline-danger" onclick="return confirm('Удалить?')">Удалить</a>
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        {% else %}
            <div class="text-center py-5">
                <h5>Пока нет проектов</h5>
                <a href="{{ url_for('admin_portfolio_add') }}" class="btn btn-primary">Добавить проект</a>
            </div>
        {% endif %}
    </div>
</div>
{% endblock %}
EOF

    # templates/admin/portfolio_form.html
    cat > /home/kododrive/kododrive-portfolio/templates/admin/portfolio_form.html << 'EOF'
{% extends "admin/layout.html" %}
{% block page_title %}
    {% if portfolio %}Редактировать проект{% else %}Добавить проект{% endif %}
{% endblock %}
{% block content %}
<div class="card">
    <div class="card-body">
        <form method="POST">
            <div class="mb-3">
                <label class="form-label">Название проекта *</label>
                <input type="text" class="form-control" name="title" value="{{ portfolio.title if portfolio else '' }}" required>
            </div>
            <div class="mb-3">
                <label class="form-label">Описание *</label>
                <textarea class="form-control" name="description" rows="4" required>{{ portfolio.description if portfolio else '' }}</textarea>
            </div>
            <div class="mb-3">
                <label class="form-label">Иконка (CSS класс)</label>
                <input type="text" class="form-control" name="icon" value="{{ portfolio.icon if portfolio else 'fas fa-code' }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Технологии (JSON)</label>
                <textarea class="form-control" name="technologies" rows="2">{{ portfolio.technologies if portfolio else '["Python", "Flask"]' }}</textarea>
            </div>
            <div class="mb-3">
                <label class="form-label">Ссылка на проект</label>
                <input type="url" class="form-control" name="project_url" value="{{ portfolio.project_url if portfolio else '' }}">
            </div>
            <div class="mb-3">
                <label class="form-label">GitHub</label>
                <input type="url" class="form-control" name="github_url" value="{{ portfolio.github_url if portfolio else '' }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Изображение</label>
                <input type="url" class="form-control" name="image_url" value="{{ portfolio.image_url if portfolio else '' }}">
            </div>
            <div class="mb-3">
                <label class="form-label">Порядок</label>
                <input type="number" class="form-control" name="order_index" value="{{ portfolio.order_index if portfolio else 0 }}">
            </div>
            {% if portfolio %}
            <div class="form-check mb-3">
                <input type="checkbox" class="form-check-input" name="is_active" {% if portfolio.is_active %}checked{% endif %}>
                <label class="form-check-label">Активен</label>
            </div>
            {% endif %}
            <div class="d-flex justify-content-between">
                <a href="{{ url_for('admin_portfolio') }}" class="btn btn-secondary">Назад</a>
                <button type="submit" class="btn btn-primary">Сохранить</button>
            </div>
        </form>
    </div>
</div>
{% endblock %}
EOF
}

# Исправленная функция настройки Flask приложения
setup_flask_app() {
    log "Настройка Flask приложения..."

    cd /home/kododrive/kododrive-portfolio

    # Создание виртуального окружения
    sudo -u kododrive python3 -m venv venv || error "Не удалось создать виртуальное окружение"

    # Установка зависимостей
    sudo -u kododrive bash -c "source venv/bin/activate && pip install --upgrade pip" || error "Не удалось обновить pip"
    sudo -u kododrive bash -c "source venv/bin/activate && pip install -r requirements.txt" || error "Не удалось установить зависимости"

    # Инициализация базы данных
    log "Инициализация миграций..."
    sudo -u kododrive bash -c "cd /home/kododrive/kododrive-portfolio && source venv/bin/activate && source .env && flask db init" || warning "Миграции уже инициализированы"

    log "Создание миграции..."
    sudo -u kododrive bash -c "cd /home/kododrive/kododrive-portfolio && source venv/bin/activate && source .env && flask db migrate -m 'Initial migration'" || warning "Миграция уже существует"

    log "Применение миграции..."
    sudo -u kododrive bash -c "cd /home/kododrive/kododrive-portfolio && source venv/bin/activate && source .env && flask db upgrade" || error "Не удалось применить миграции"

    # Создание начальных данных
    log "Создание начальных данных..."
    sudo -u kododrive bash -c "cd /home/kododrive/kododrive-portfolio && source venv/bin/activate && source .env && python3 -c \"
from app import app, db, User, create_initial_data
from werkzeug.security import generate_password_hash
import os

with app.app_context():
    if User.query.count() == 0:
        admin = User(
            username='admin',
            password_hash=generate_password_hash(os.environ.get('ADMIN_PASSWORD', 'admin123')),
            is_admin=True
        )
        db.session.add(admin)
        create_initial_data()
        db.session.commit()
        print('Администратор и начальные данные созданы')
    else:
        print('Данные уже существуют')
\"" || error "Не удалось создать начальные данные"

    log "Flask приложение настроено"
}

# Исправленная функция создания systemd сервиса
create_systemd_service() {
    log "Создание systemd сервиса..."

    cat > /etc/systemd/system/kododrive.service << EOF
[Unit]
Description=KodoDrive Portfolio Flask App
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=kododrive
Group=kododrive
WorkingDirectory=/home/kododrive/kododrive-portfolio
Environment="PATH=/home/kododrive/kododrive-portfolio/venv/bin"
EnvironmentFile=/home/kododrive/kododrive-portfolio/.env
ExecStart=/home/kododrive/kododrive-portfolio/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 --timeout 120 wsgi:app
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || error "Не удалось перезагрузить systemd"
    systemctl enable kododrive || error "Не удалось включить автозапуск сервиса"

    log "Systemd сервис создан"
}

# Исправленная функция настройки Nginx
setup_nginx() {
    log "Настройка Nginx..."

    # Создание конфигурации Nginx без SSL (сначала)
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /home/kododrive/kododrive-portfolio;

    # Статические файлы
    location /static/ {
        alias /home/kododrive/kododrive-portfolio/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";

        # CORS заголовки для статических файлов
        add_header Access-Control-Allow-Origin "*";
    }

    location /favicon.ico {
        alias /home/kododrive/kododrive-portfolio/static/favicon.ico;
        expires 1y;
    }

    # Основной прокси
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types 
        text/plain 
        text/css 
        text/xml 
        text/javascript 
        application/javascript 
        application/json
        application/xml+rss;
}
EOF

    # Активация сайта
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/ || error "Не удалось активировать сайт"
    rm -f /etc/nginx/sites-enabled/default

    # Тестирование конфигурации
    nginx -t || error "Ошибка в конфигурации Nginx"

    log "Nginx настроен (HTTP)"
}

# Исправленная функция настройки SSL
setup_ssl() {
    log "Получение SSL сертификата..."

    # Запуск Flask приложения и Nginx
    systemctl start kododrive || error "Не удалось запустить Flask приложение"
    systemctl restart nginx || error "Не удалось перезапустить Nginx"

    # Даем время приложению запуститься
    sleep 10

    # Проверка работы Flask
    if ! curl -f http://127.0.0.1:5000 >/dev/null 2>&1; then
        error "Flask приложение не отвечает на порту 5000"
    fi

    # Получение сертификата через nginx plugin
    certbot --nginx --agree-tos --no-eff-email --email $EMAIL -d $DOMAIN -d www.$DOMAIN || error "Не удалось получить SSL сертификат"

    # Обновление конфигурации Nginx для SSL
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_private_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip сжатие
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types 
        text/plain 
        text/css 
        text/xml 
        text/javascript 
        application/javascript 
        application/json
        application/xml+rss;

    root /home/kododrive/kododrive-portfolio;

    # Статические файлы с правильными правами доступа
    location /static/ {
        alias /home/kododrive/kododrive-portfolio/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";

        # Разрешаем Nginx читать файлы пользователя kododrive
        access_log off;
    }

    location /favicon.ico {
        alias /home/kododrive/kododrive-portfolio/static/favicon.ico;
        expires 1y;
        access_log off;
    }

    # Основной прокси к Flask приложению
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
}
EOF

    # Установка автообновления SSL сертификата
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab - || warning "Не удалось настроить автообновление SSL"

    systemctl reload nginx || error "Не удалось перезагрузить Nginx с SSL конфигурацией"

    log "SSL настроен успешно"
}

# Исправленная функция настройки безопасности
setup_security() {
    log "Настройка безопасности..."

    # Настройка прав доступа для статических файлов
    chmod -R 755 /home/kododrive/kododrive-portfolio/static/
    chown -R kododrive:www-data /home/kododrive/kododrive-portfolio/static/

    # Добавление nginx в группу kododrive для доступа к файлам
    usermod -a -G kododrive www-data

    # Firewall
    ufw --force enable || error "Не удалось включить firewall"
    ufw allow 22 || error "Не удалось разрешить SSH"
    ufw allow 80 || error "Не удалось разрешить HTTP" 
    ufw allow 443 || error "Не удалось разрешить HTTPS"

    # Создание скриптов
    mkdir -p /home/kododrive/scripts

    # Скрипт резервного копирования
    cat > /home/kododrive/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/kododrive/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Starting backup: $DATE"

# Бэкап базы данных
sudo -u postgres pg_dump kododrive_db > $BACKUP_DIR/db_backup_$DATE.sql
echo "Database backup completed"

# Бэкап файлов приложения  
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz -C /home/kododrive kododrive-portfolio --exclude=kododrive-portfolio/venv --exclude=kododrive-portfolio/__pycache__ --exclude=kododrive-portfolio/*.pyc
echo "Application backup completed"

# Удаление старых бэкапов (старше 7 дней)
find $BACKUP_DIR -type f -mtime +7 -delete
echo "Old backups cleaned"

echo "Backup completed: $DATE"
EOF

    # Скрипт обновления
    cat > /home/kododrive/scripts/update.sh << 'EOF'
#!/bin/bash
cd /home/kododrive/kododrive-portfolio

echo "Starting update..."

# Активация виртуального окружения
source venv/bin/activate
source .env

# Установка/обновление зависимостей
pip install --upgrade pip
pip install -r requirements.txt
echo "Dependencies updated"

# Применение миграций
flask db upgrade
echo "Database migrations applied"

# Перезапуск сервиса
sudo systemctl restart kododrive
echo "Service restarted"

# Проверка статуса
sleep 5
sudo systemctl status kododrive --no-pager
echo "Update completed!"
EOF

    # Скрипт проверки статуса
    cat > /home/kododrive/scripts/status.sh << 'EOF'
#!/bin/bash
echo "=== KodoDrive Status ==="
echo ""
echo "Flask App:"
sudo systemctl status kododrive --no-pager -l
echo ""
echo "Nginx:"
sudo systemctl status nginx --no-pager -l
echo ""
echo "PostgreSQL:"
sudo systemctl status postgresql --no-pager -l
echo ""
echo "Disk Usage:"
df -h /home/kododrive/
echo ""
echo "Memory Usage:"
free -h
EOF

    chmod +x /home/kododrive/scripts/*.sh
    chown -R kododrive:kododrive /home/kododrive/scripts/

    # Добавление cron job для бэкапа
    sudo -u kododrive bash -c '(crontab -l 2>/dev/null; echo "0 2 * * * /home/kododrive/scripts/backup.sh >> /home/kododrive/backup.log 2>&1") | crontab -' || warning "Не удалось настроить cron для бэкапа"

    log "Безопасность и скрипты настроены"
}

# Функция создания favicon
create_favicon() {
    log "Создание простого favicon..."

    # Создаем минимальный ICO файл (16x16, просто синий квадрат)
    echo -e '\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x01\x00\x08\x00h\x00\x00\x00\x16\x00\x00\x00(\x00\x00\x00\x10\x00\x00\x00 \x00\x00\x00\x01\x00\x08\x00\x00\x00\x00\x00@\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00fff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > /home/kododrive/kododrive-portfolio/static/favicon.ico

    chown kododrive:kododrive /home/kododrive/kododrive-portfolio/static/favicon.ico
    log "Favicon создан"
}

# Главная функция установки с расширенной диагностикой
main() {
    log "Начинаем установку KodoDrive Portfolio v2.0 (исправленная версия)..."

    # Выполнение всех шагов установки
    create_user
    update_system
    install_packages
    setup_postgresql
    create_project_structure
    create_python_files
    create_templates
    create_static_files
    create_favicon
    setup_flask_app
    create_systemd_service

    # Запуск Flask приложения перед настройкой Nginx
    log "Запуск Flask приложения..."
    systemctl start kododrive || error "Не удалось запустить Flask приложение"

    setup_nginx
    setup_ssl
    setup_security

    # Финальная проверка всех сервисов
    log "Выполнение финальных проверок..."

    # Проверка Flask приложения
    if systemctl is-active --quiet kododrive; then
        log "✓ Flask приложение работает"
    else
        error "✗ Flask приложение не работает"
    fi

    # Проверка Nginx
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx работает"
    else
        error "✗ Nginx не работает"
    fi

    # Проверка PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log "✓ PostgreSQL работает"
    else
        error "✗ PostgreSQL не работает"
    fi

    # Проверка доступности сайта
    if curl -f -k https://$DOMAIN >/dev/null 2>&1; then
        log "✓ Сайт доступен через HTTPS"
    else
        warning "⚠ Сайт может быть недоступен через HTTPS, проверьте DNS настройки"
    fi

    # Проверка статических файлов
    if curl -f -k https://$DOMAIN/static/css/style.css >/dev/null 2>&1; then
        log "✓ Статические файлы (CSS) доступны"
    else
        error "✗ Статические файлы (CSS) недоступны - основная проблема решена!"
    fi

    if curl -f -k https://$DOMAIN/static/js/script.js >/dev/null 2>&1; then
        log "✓ Статические файлы (JS) доступны"
    else
        error "✗ Статические файлы (JS) недоступны"
    fi

    # Вывод итоговой информации
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! (v2.0 FIXED) 🎉                  ║
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
    info "   • Перезапуск приложения: sudo systemctl restart kododrive"
    info "   • Просмотр логов: sudo journalctl -u kododrive -f"
    info "   • Проверка статуса: /home/kododrive/scripts/status.sh"
    info "   • Обновление: /home/kododrive/scripts/update.sh"
    info "   • Бэкап: /home/kododrive/scripts/backup.sh"
    echo ""
    info "🐛 Исправленные проблемы:"
    info "   • ✅ Nginx конфигурация исправлена"
    info "   • ✅ Права доступа к статическим файлам настроены"
    info "   • ✅ CSS и JS файлы теперь загружаются корректно"
    info "   • ✅ Flask приложение стабильно работает"
    info "   • ✅ База данных и миграции настроены"
    echo ""
    warning "⚠️  Рекомендации:"
    warning "   • Смените пароль администратора после входа"
    warning "   • Настройте DNS записи для домена $DOMAIN на IP $SERVER_IP"
    warning "   • Проверьте работу сайта через несколько минут после установки"
    echo ""
    log "🚀 Установка завершена! Добро пожаловать в KodoDrive Portfolio!"

    # Показать логи для диагностики
    echo ""
    info "📋 Последние логи Flask приложения:"
    journalctl -u kododrive --no-pager -l --since "5 minutes ago" || true
}

# Запуск основной функции
main

exit 0
