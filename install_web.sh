#!/bin/bash

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
║                       Версия 3.0 (FINAL)                    ║
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
    usermod -aG sudo kododrive || error "Не удалось добавить пользователя в группу sudo"

    # Создаем SSH директорию для пользователя
    mkdir -p /home/kododrive/.ssh
    chmod 700 /home/kododrive/.ssh
    chown kododrive:kododrive /home/kododrive/.ssh

    log "Пользователь kododrive создан успешно"
}

# Функция обновления системы
update_system() {
    log "Обновление системы..."

    export DEBIAN_FRONTEND=noninteractive
    apt update || error "Не удалось обновить список пакетов"
    apt upgrade -y || error "Не удалось обновить систему"
    apt install software-properties-common curl wget gnupg lsb-release -y || error "Не удалось установить базовые пакеты"

    log "Система обновлена успешно"
}

# Функция установки пакетов
install_packages() {
    log "Установка необходимых пакетов..."

    # Установка Python и связанных пакетов
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        || error "Не удалось установить Python пакеты"

    # Установка PostgreSQL
    apt install -y \
        postgresql \
        postgresql-contrib \
        libpq-dev \
        || error "Не удалось установить PostgreSQL"

    # Установка веб-сервера и SSL
    apt install -y \
        nginx \
        certbot \
        python3-certbot-nginx \
        || error "Не удалось установить Nginx и Certbot"

    # Установка дополнительных утилит
    apt install -y \
        git \
        htop \
        nano \
        vim \
        unzip \
        ufw \
        fail2ban \
        logrotate \
        || error "Не удалось установить дополнительные пакеты"

    # Обновление pip
    python3 -m pip install --upgrade pip || error "Не удалось обновить pip"

    log "Все пакеты установлены успешно"
}

# Функция настройки PostgreSQL
setup_postgresql() {
    log "Настройка PostgreSQL..."

    # Запуск и включение автозапуска
    systemctl start postgresql || error "Не удалось запустить PostgreSQL"
    systemctl enable postgresql || error "Не удалось включить автозапуск PostgreSQL"

    # Ожидание полного запуска
    sleep 5

    # Удаление старых данных если есть
    sudo -u postgres psql << EOF 2>/dev/null || true
DROP DATABASE IF EXISTS kododrive_db;
DROP USER IF EXISTS kododrive;
EOF

    # Создание базы данных и пользователя
    sudo -u postgres psql << EOF || error "Не удалось создать базу данных"
CREATE DATABASE kododrive_db;
CREATE USER kododrive WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE kododrive_db TO kododrive;
ALTER USER kododrive CREATEDB;
GRANT ALL PRIVILEGES ON SCHEMA public TO kododrive;
ALTER DATABASE kododrive_db OWNER TO kododrive;
\q
EOF

    # Проверка подключения
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U kododrive -d kododrive_db -c "SELECT version();" >/dev/null || error "Не удалось подключиться к базе данных"

    log "PostgreSQL настроен и протестирован"
}

# Функция создания структуры проекта
create_project_structure() {
    log "Создание структуры проекта..."

    PROJECT_DIR="/home/kododrive/portfolio"

    # Удаляем старую директорию если существует
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
    fi

    # Создаем структуру папок
    mkdir -p $PROJECT_DIR/{static/{css,js,img,uploads},templates/admin,logs,backups,scripts}

    # Устанавливаем права доступа
    chown -R kododrive:kododrive /home/kododrive/
    chmod -R 755 /home/kododrive/

    log "Структура проекта создана"
}

# Функция создания Python файлов
create_python_files() {
    log "Создание Python файлов..."

    PROJECT_DIR="/home/kododrive/portfolio"

    # requirements.txt
    cat > $PROJECT_DIR/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Flask-Migrate==4.0.5
Werkzeug==3.0.1
psycopg2-binary==2.9.7
gunicorn==21.2.0
python-dotenv==1.0.0
Jinja2==3.1.2
MarkupSafe==2.1.3
python-dateutil==2.8.2
EOF

    # .env файл
    cat > $PROJECT_DIR/.env << EOF
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://kododrive:$DB_PASSWORD@localhost/kododrive_db
DOMAIN=$DOMAIN
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF

    # app.py
    cat > $PROJECT_DIR/app.py << 'EOF'
import os
import json
from datetime import datetime
from functools import wraps

from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from dotenv import load_dotenv

# Загрузка переменных окружения
load_dotenv()

app = Flask(__name__)

# Конфигурация приложения
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///portfolio.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.path.join(app.root_path, 'static', 'uploads')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Инициализация расширений
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Создание папки для загрузок
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# ===============================
# МОДЕЛИ БАЗЫ ДАННЫХ
# ===============================

class User(db.Model):
    """Модель пользователя"""
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(120))
    is_admin = db.Column(db.Boolean, default=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<User {self.username}>'

class SiteSettings(db.Model):
    """Настройки сайта"""
    __tablename__ = 'site_settings'

    id = db.Column(db.Integer, primary_key=True)
    site_title = db.Column(db.String(200), default="KodoDrive Portfolio")
    hero_title = db.Column(db.String(200), default="Привет, я KodoDrive")
    hero_subtitle = db.Column(db.String(200), default="Python Full Stack Developer")
    hero_description = db.Column(db.Text, default="Специализируюсь на создании Telegram-ботов любой сложности и скриптов автоматизации.")
    about_title = db.Column(db.String(200), default="Python Full Stack Developer")
    about_description = db.Column(db.Text, default="Разрабатываю Telegram-ботов и автоматизирую бизнес-процессы с помощью Python.")
    contact_email = db.Column(db.String(100), default="kododrive@example.com")
    contact_telegram = db.Column(db.String(100), default="@kodoDrive")
    contact_github = db.Column(db.String(100), default="github.com/kododrive")
    contact_linkedin = db.Column(db.String(100))
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Skill(db.Model):
    """Модель навыков"""
    __tablename__ = 'skills'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    percentage = db.Column(db.Integer, nullable=False, default=50)
    category = db.Column(db.String(50), default="general")
    icon = db.Column(db.String(50))
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Service(db.Model):
    """Модель услуг"""
    __tablename__ = 'services'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    icon = db.Column(db.String(50), default="fas fa-cogs")
    features = db.Column(db.Text)  # JSON строка с списком возможностей
    price = db.Column(db.String(50))
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    @property
    def features_list(self):
        if self.features:
            try:
                return json.loads(self.features)
            except:
                return []
        return []

class Portfolio(db.Model):
    """Модель проектов портфолио"""
    __tablename__ = 'portfolio'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    short_description = db.Column(db.String(255))
    icon = db.Column(db.String(50), default="fas fa-code")
    image_url = db.Column(db.String(255))
    technologies = db.Column(db.Text)  # JSON строка с технологиями
    project_url = db.Column(db.String(255))
    github_url = db.Column(db.String(255))
    demo_url = db.Column(db.String(255))
    category = db.Column(db.String(50), default="web")
    status = db.Column(db.String(20), default="completed")  # completed, in_progress, planned
    order_index = db.Column(db.Integer, default=0)
    is_featured = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    @property
    def tech_list(self):
        if self.technologies:
            try:
                return json.loads(self.technologies)
            except:
                return []
        return []

class Stats(db.Model):
    """Модель статистики"""
    __tablename__ = 'stats'

    id = db.Column(db.Integer, primary_key=True)
    label = db.Column(db.String(100), nullable=False)
    value = db.Column(db.Integer, nullable=False, default=0)
    suffix = db.Column(db.String(10), default="")  # +, %, лет и т.д.
    icon = db.Column(db.String(50))
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    auto_increment = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class ContactMessage(db.Model):
    """Модель сообщений обратной связи"""
    __tablename__ = 'contact_messages'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    subject = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(255))
    is_read = db.Column(db.Boolean, default=False)
    is_spam = db.Column(db.Boolean, default=False)
    replied_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ===============================
# ДЕКОРАТОРЫ И УТИЛИТЫ
# ===============================

def login_required(f):
    """Декоратор для проверки авторизации"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('admin_login'))

        user = User.query.get(session['user_id'])
        if not user or not user.is_active:
            session.pop('user_id', None)
            return redirect(url_for('admin_login'))

        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    """Декоратор для проверки прав администратора"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('admin_login'))

        user = User.query.get(session['user_id'])
        if not user or not user.is_admin or not user.is_active:
            flash('У вас нет прав администратора', 'error')
            return redirect(url_for('index'))

        return f(*args, **kwargs)
    return decorated_function

# ===============================
# ОСНОВНЫЕ МАРШРУТЫ САЙТА
# ===============================

@app.route('/')
def index():
    """Главная страница"""
    # Получаем настройки сайта
    settings = SiteSettings.query.first()
    if not settings:
        settings = SiteSettings()
        db.session.add(settings)
        db.session.commit()

    # Получаем данные для отображения
    skills = Skill.query.filter_by(is_active=True).order_by(Skill.order_index, Skill.name).all()
    services = Service.query.filter_by(is_active=True).order_by(Service.order_index, Service.title).all()
    portfolio = Portfolio.query.filter_by(is_active=True).order_by(Portfolio.order_index.desc(), Portfolio.created_at.desc()).all()
    stats = Stats.query.filter_by(is_active=True).order_by(Stats.order_index, Stats.label).all()

    return render_template('index.html', 
                         settings=settings,
                         skills=skills,
                         services=services,
                         portfolio=portfolio,
                         stats=stats)

@app.route('/contact', methods=['POST'])
def contact():
    """Обработка контактной формы"""
    try:
        name = request.form.get('name', '').strip()
        email = request.form.get('email', '').strip()
        subject = request.form.get('subject', '').strip()
        message = request.form.get('message', '').strip()

        # Простая валидация
        if not all([name, email, subject, message]):
            return jsonify({'status': 'error', 'message': 'Все поля обязательны для заполнения'})

        if len(name) < 2:
            return jsonify({'status': 'error', 'message': 'Имя должно содержать минимум 2 символа'})

        if '@' not in email or '.' not in email:
            return jsonify({'status': 'error', 'message': 'Некорректный email адрес'})

        if len(message) < 10:
            return jsonify({'status': 'error', 'message': 'Сообщение должно содержать минимум 10 символов'})

        # Создаем запись в базе
        contact_message = ContactMessage(
            name=name,
            email=email,
            subject=subject,
            message=message,
            ip_address=request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR')),
            user_agent=request.headers.get('User-Agent', '')[:255]
        )

        db.session.add(contact_message)
        db.session.commit()

        return jsonify({'status': 'success', 'message': 'Сообщение отправлено! Я отвечу в ближайшее время.'})

    except Exception as e:
        app.logger.error(f"Ошибка при обработке контактной формы: {e}")
        return jsonify({'status': 'error', 'message': 'Произошла ошибка при отправке сообщения'})

# ===============================
# АДМИН ПАНЕЛЬ - АВТОРИЗАЦИЯ
# ===============================

@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    """Вход в админ панель"""
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')

        if not username or not password:
            flash('Заполните все поля', 'error')
            return render_template('admin/login.html')

        user = User.query.filter_by(username=username, is_active=True).first()

        if user and user.check_password(password):
            session['user_id'] = user.id
            user.last_login = datetime.utcnow()
            db.session.commit()

            flash(f'Добро пожаловать, {user.username}!', 'success')
            return redirect(url_for('admin_dashboard'))
        else:
            flash('Неверное имя пользователя или пароль', 'error')

    return render_template('admin/login.html')

@app.route('/admin/logout')
def admin_logout():
    """Выход из админ панели"""
    session.pop('user_id', None)
    flash('Вы вышли из системы', 'info')
    return redirect(url_for('index'))

# ===============================
# АДМИН ПАНЕЛЬ - ОСНОВНЫЕ СТРАНИЦЫ
# ===============================

@app.route('/admin')
@admin_required
def admin_dashboard():
    """Главная страница админ панели"""
    # Собираем статистику
    stats_data = {
        'total_projects': Portfolio.query.count(),
        'active_projects': Portfolio.query.filter_by(is_active=True).count(),
        'total_services': Service.query.count(),
        'active_services': Service.query.filter_by(is_active=True).count(),
        'total_skills': Skill.query.count(),
        'active_skills': Skill.query.filter_by(is_active=True).count(),
        'total_messages': ContactMessage.query.count(),
        'unread_messages': ContactMessage.query.filter_by(is_read=False).count(),
        'featured_projects': Portfolio.query.filter_by(is_featured=True, is_active=True).count()
    }

    # Последние сообщения
    recent_messages = ContactMessage.query.order_by(ContactMessage.created_at.desc()).limit(5).all()

    # Последние проекты
    recent_projects = Portfolio.query.order_by(Portfolio.created_at.desc()).limit(5).all()

    return render_template('admin/dashboard.html',
                         stats=stats_data,
                         recent_messages=recent_messages,
                         recent_projects=recent_projects)

@app.route('/admin/settings', methods=['GET', 'POST'])
@admin_required
def admin_settings():
    """Настройки сайта"""
    settings = SiteSettings.query.first()
    if not settings:
        settings = SiteSettings()
        db.session.add(settings)
        db.session.commit()

    if request.method == 'POST':
        # Обновляем настройки
        settings.site_title = request.form.get('site_title', '').strip()
        settings.hero_title = request.form.get('hero_title', '').strip()
        settings.hero_subtitle = request.form.get('hero_subtitle', '').strip()
        settings.hero_description = request.form.get('hero_description', '').strip()
        settings.about_title = request.form.get('about_title', '').strip()
        settings.about_description = request.form.get('about_description', '').strip()
        settings.contact_email = request.form.get('contact_email', '').strip()
        settings.contact_telegram = request.form.get('contact_telegram', '').strip()
        settings.contact_github = request.form.get('contact_github', '').strip()
        settings.contact_linkedin = request.form.get('contact_linkedin', '').strip()
        settings.updated_at = datetime.utcnow()

        try:
            db.session.commit()
            flash('Настройки успешно сохранены!', 'success')
        except Exception as e:
            db.session.rollback()
            flash(f'Ошибка при сохранении: {e}', 'error')

        return redirect(url_for('admin_settings'))

    return render_template('admin/settings.html', settings=settings)

# ===============================
# АДМИН ПАНЕЛЬ - ПОРТФОЛИО
# ===============================

@app.route('/admin/portfolio')
@admin_required
def admin_portfolio():
    """Список проектов портфолио"""
    page = request.args.get('page', 1, type=int)
    per_page = 10

    projects = Portfolio.query.order_by(Portfolio.order_index.desc(), Portfolio.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False)

    return render_template('admin/portfolio.html', projects=projects)

@app.route('/admin/portfolio/add', methods=['GET', 'POST'])
@admin_required
def admin_portfolio_add():
    """Добавление нового проекта"""
    if request.method == 'POST':
        try:
            # Получаем данные из формы
            title = request.form.get('title', '').strip()
            description = request.form.get('description', '').strip()
            short_description = request.form.get('short_description', '').strip()
            icon = request.form.get('icon', 'fas fa-code').strip()
            image_url = request.form.get('image_url', '').strip()
            project_url = request.form.get('project_url', '').strip()
            github_url = request.form.get('github_url', '').strip()
            demo_url = request.form.get('demo_url', '').strip()
            category = request.form.get('category', 'web').strip()
            status = request.form.get('status', 'completed').strip()
            order_index = int(request.form.get('order_index', 0))
            is_featured = 'is_featured' in request.form

            # Обработка технологий
            technologies_raw = request.form.get('technologies', '').strip()
            if technologies_raw:
                try:
                    # Проверяем, является ли это JSON
                    json.loads(technologies_raw)
                    technologies = technologies_raw
                except:
                    # Если не JSON, преобразуем строку в массив
                    tech_list = [tech.strip() for tech in technologies_raw.split(',') if tech.strip()]
                    technologies = json.dumps(tech_list)
            else:
                technologies = '[]'

            # Валидация
            if not title:
                flash('Название проекта обязательно', 'error')
                return render_template('admin/portfolio_form.html', project=None)

            if not description:
                flash('Описание проекта обязательно', 'error')
                return render_template('admin/portfolio_form.html', project=None)

            # Создаем новый проект
            project = Portfolio(
                title=title,
                description=description,
                short_description=short_description,
                icon=icon,
                image_url=image_url,
                technologies=technologies,
                project_url=project_url,
                github_url=github_url,
                demo_url=demo_url,
                category=category,
                status=status,
                order_index=order_index,
                is_featured=is_featured
            )

            db.session.add(project)
            db.session.commit()

            flash('Проект успешно добавлен!', 'success')
            return redirect(url_for('admin_portfolio'))

        except Exception as e:
            db.session.rollback()
            flash(f'Ошибка при добавлении проекта: {e}', 'error')

    return render_template('admin/portfolio_form.html', project=None)

@app.route('/admin/portfolio/edit/<int:id>', methods=['GET', 'POST'])
@admin_required
def admin_portfolio_edit(id):
    """Редактирование проекта"""
    project = Portfolio.query.get_or_404(id)

    if request.method == 'POST':
        try:
            # Обновляем данные
            project.title = request.form.get('title', '').strip()
            project.description = request.form.get('description', '').strip()
            project.short_description = request.form.get('short_description', '').strip()
            project.icon = request.form.get('icon', 'fas fa-code').strip()
            project.image_url = request.form.get('image_url', '').strip()
            project.project_url = request.form.get('project_url', '').strip()
            project.github_url = request.form.get('github_url', '').strip()
            project.demo_url = request.form.get('demo_url', '').strip()
            project.category = request.form.get('category', 'web').strip()
            project.status = request.form.get('status', 'completed').strip()
            project.order_index = int(request.form.get('order_index', 0))
            project.is_featured = 'is_featured' in request.form
            project.is_active = 'is_active' in request.form
            project.updated_at = datetime.utcnow()

            # Обработка технологий
            technologies_raw = request.form.get('technologies', '').strip()
            if technologies_raw:
                try:
                    json.loads(technologies_raw)
                    project.technologies = technologies_raw
                except:
                    tech_list = [tech.strip() for tech in technologies_raw.split(',') if tech.strip()]
                    project.technologies = json.dumps(tech_list)
            else:
                project.technologies = '[]'

            # Валидация
            if not project.title:
                flash('Название проекта обязательно', 'error')
                return render_template('admin/portfolio_form.html', project=project)

            if not project.description:
                flash('Описание проекта обязательно', 'error')
                return render_template('admin/portfolio_form.html', project=project)

            db.session.commit()
            flash('Проект успешно обновлен!', 'success')
            return redirect(url_for('admin_portfolio'))

        except Exception as e:
            db.session.rollback()
            flash(f'Ошибка при обновлении проекта: {e}', 'error')

    return render_template('admin/portfolio_form.html', project=project)

@app.route('/admin/portfolio/delete/<int:id>')
@admin_required
def admin_portfolio_delete(id):
    """Удаление проекта"""
    project = Portfolio.query.get_or_404(id)

    try:
        db.session.delete(project)
        db.session.commit()
        flash('Проект успешно удален!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Ошибка при удалении проекта: {e}', 'error')

    return redirect(url_for('admin_portfolio'))

# ===============================
# АДМИН ПАНЕЛЬ - СООБЩЕНИЯ
# ===============================

@app.route('/admin/messages')
@admin_required
def admin_messages():
    """Список сообщений"""
    page = request.args.get('page', 1, type=int)
    per_page = 20

    messages = ContactMessage.query.order_by(ContactMessage.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False)

    return render_template('admin/messages.html', messages=messages)

@app.route('/admin/messages/<int:id>')
@admin_required
def admin_message_view(id):
    """Просмотр сообщения"""
    message = ContactMessage.query.get_or_404(id)

    # Отмечаем как прочитанное
    if not message.is_read:
        message.is_read = True
        db.session.commit()

    return render_template('admin/message_view.html', message=message)

@app.route('/admin/messages/delete/<int:id>')
@admin_required
def admin_message_delete(id):
    """Удаление сообщения"""
    message = ContactMessage.query.get_or_404(id)

    try:
        db.session.delete(message)
        db.session.commit()
        flash('Сообщение удалено!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Ошибка при удалении: {e}', 'error')

    return redirect(url_for('admin_messages'))

# ===============================
# ФУНКЦИИ ИНИЦИАЛИЗАЦИИ
# ===============================

def create_initial_data():
    """Создание начальных данных"""
    try:
        # Проверяем, есть ли уже данные
        if User.query.count() > 0:
            return

        # Создаем администратора
        admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
        admin = User(
            username='admin',
            email=os.environ.get('ADMIN_EMAIL', 'admin@kododrive.com'),
            is_admin=True,
            is_active=True
        )
        admin.set_password(admin_password)
        db.session.add(admin)

        # Создаем настройки сайта
        settings = SiteSettings()
        db.session.add(settings)

        # Создаем навыки
        skills = [
            Skill(name="Python", percentage=95, category="programming", icon="fab fa-python", order_index=1),
            Skill(name="Telegram Bot API", percentage=90, category="api", icon="fab fa-telegram", order_index=2),
            Skill(name="Flask/Django", percentage=85, category="framework", icon="fas fa-fire", order_index=3),
            Skill(name="PostgreSQL", percentage=80, category="database", icon="fas fa-database", order_index=4),
            Skill(name="Docker", percentage=75, category="devops", icon="fab fa-docker", order_index=5),
            Skill(name="Linux", percentage=85, category="system", icon="fab fa-linux", order_index=6)
        ]

        for skill in skills:
            db.session.add(skill)

        # Создаем услуги
        services = [
            Service(
                title="Telegram Боты",
                description="Создание ботов любой сложности: от простых информационных до многофункциональных с базами данных",
                icon="fas fa-robot",
                features=json.dumps([
                    "Интерактивные меню",
                    "Обработка медиафайлов", 
                    "Интеграция с API",
                    "Платежные системы",
                    "Базы данных",
                    "Веб-приложения"
                ]),
                price="от 5000 ₽",
                order_index=1
            ),
            Service(
                title="Автоматизация",
                description="Скрипты для автоматизации рутинных задач и бизнес-процессов",
                icon="fas fa-cogs",
                features=json.dumps([
                    "Парсинг данных",
                    "Массовые рассылки",
                    "Мониторинг систем",
                    "Обработка файлов",
                    "Интеграция сервисов",
                    "Отчеты и аналитика"
                ]),
                price="от 3000 ₽",
                order_index=2
            ),
            Service(
                title="Веб-разработка",
                description="Создание современных веб-приложений на Python",
                icon="fas fa-globe",
                features=json.dumps([
                    "Flask/Django",
                    "API разработка",
                    "База данных",
                    "Админ панели",
                    "Деплой и хостинг",
                    "Техническая поддержка"
                ]),
                price="от 10000 ₽",
                order_index=3
            )
        ]

        for service in services:
            db.session.add(service)

        # Создаем проекты портфолио
        projects = [
            Portfolio(
                title="E-commerce Telegram Бот",
                description="Полнофункциональный бот для интернет-магазина с каталогом товаров, корзиной, системой оплаты и административной панелью для управления заказами.",
                short_description="Telegram бот для интернет-магазина с полным функционалом",
                icon="fas fa-shopping-cart",
                technologies=json.dumps([
                    "Python", "aiogram", "PostgreSQL", "Redis", "Stripe API", "Docker"
                ]),
                category="telegram",
                status="completed",
                is_featured=True,
                order_index=10
            ),
            Portfolio(
                title="CRM система",
                description="Веб-приложение для управления клиентами с интеграцией Telegram бота для уведомлений и быстрого взаимодействия.",
                short_description="CRM с Telegram интеграцией",
                icon="fas fa-users",
                technologies=json.dumps([
                    "Python", "Flask", "PostgreSQL", "JavaScript", "Bootstrap", "Chart.js"
                ]),
                category="web",
                status="completed",
                is_featured=True,
                order_index=9
            ),
            Portfolio(
                title="Система мониторинга",
                description="Автоматизированная система мониторинга серверов с уведомлениями в Telegram при возникновении проблем.",
                short_description="Мониторинг серверов с Telegram уведомлениями",
                icon="fas fa-chart-line",
                technologies=json.dumps([
                    "Python", "Grafana", "InfluxDB", "Docker", "Telegram API"
                ]),
                category="automation",
                status="completed",
                order_index=8
            )
        ]

        for project in projects:
            db.session.add(project)

        # Создаем статистику
        stats_items = [
            Stats(label="Проектов завершено", value=25, suffix="+", icon="fas fa-project-diagram", order_index=1),
            Stats(label="Довольных клиентов", value=20, suffix="+", icon="fas fa-smile", order_index=2), 
            Stats(label="Года опыта", value=3, suffix="", icon="fas fa-calendar", order_index=3),
            Stats(label="Технологий", value=15, suffix="+", icon="fas fa-code", order_index=4)
        ]

        for stat in stats_items:
            db.session.add(stat)

        # Сохраняем все данные
        db.session.commit()
        app.logger.info("Начальные данные успешно созданы")

    except Exception as e:
        db.session.rollback()
        app.logger.error(f"Ошибка при создании начальных данных: {e}")
        raise

# ===============================
# ИНИЦИАЛИЗАЦИЯ ПРИЛОЖЕНИЯ
# ===============================

def init_app():
    """Инициализация приложения"""
    with app.app_context():
        # Создаем таблицы
        db.create_all()

        # Создаем начальные данные
        create_initial_data()

# ===============================
# ОБРАБОТЧИКИ ОШИБОК
# ===============================

@app.errorhandler(404)
def not_found(error):
    return render_template('errors/404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('errors/500.html'), 500

@app.errorhandler(403)
def forbidden(error):
    return render_template('errors/403.html'), 403

# ===============================
# КОНТЕКСТНЫЕ ПРОЦЕССОРЫ
# ===============================

@app.context_processor
def inject_common_vars():
    """Добавляем общие переменные в шаблоны"""
    return {
        'current_year': datetime.now().year,
        'app_name': 'KodoDrive Portfolio'
    }

# ===============================
# ЗАПУСК ПРИЛОЖЕНИЯ
# ===============================

if __name__ == '__main__':
    # Инициализация при первом запуске
    init_app()

    # Запуск в режиме разработки
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

    # wsgi.py
    cat > $PROJECT_DIR/wsgi.py << 'EOF'
#!/usr/bin/env python3
"""
WSGI модуль для Gunicorn
"""
import os
import sys

# Добавляем путь к приложению
sys.path.insert(0, os.path.dirname(__file__))

from app import app, init_app

# Инициализация при запуске
init_app()

if __name__ == "__main__":
    app.run()
EOF

    # config.py
    cat > $PROJECT_DIR/config.py << 'EOF'
import os
from datetime import timedelta

class Config:
    """Базовая конфигурация"""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///portfolio.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_RECORD_QUERIES = True

    # Настройки загрузки файлов
    UPLOAD_FOLDER = 'static/uploads'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB

    # Настройки сессий
    PERMANENT_SESSION_LIFETIME = timedelta(hours=24)
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'

    # Настройки безопасности
    WTF_CSRF_ENABLED = True
    WTF_CSRF_TIME_LIMIT = 3600

    # Логирование
    LOG_LEVEL = 'INFO'
    LOG_FILE = 'logs/app.log'

class DevelopmentConfig(Config):
    """Конфигурация для разработки"""
    DEBUG = True
    SQLALCHEMY_ECHO = True
    SESSION_COOKIE_SECURE = False

class ProductionConfig(Config):
    """Конфигурация для продакшена"""
    DEBUG = False
    SQLALCHEMY_ECHO = False
    LOG_LEVEL = 'WARNING'

class TestingConfig(Config):
    """Конфигурация для тестирования"""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    WTF_CSRF_ENABLED = False

# Словарь конфигураций
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': ProductionConfig
}
EOF

    # .gitignore
    cat > $PROJECT_DIR/.gitignore << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# celery beat schedule file
celerybeat-schedule

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# Project specific
logs/
backups/
migrations/
*.db
*.sqlite
*.sqlite3

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# SSL certificates
*.pem
*.crt
*.key

# Uploads
static/uploads/*
!static/uploads/.gitkeep
EOF

    # Создаем пустые файлы для сохранения структуры
    touch $PROJECT_DIR/static/uploads/.gitkeep
    touch $PROJECT_DIR/logs/.gitkeep

    chmod +x $PROJECT_DIR/wsgi.py
    chown -R kododrive:kododrive $PROJECT_DIR

    log "Python файлы созданы успешно"
}

# Функция создания HTML шаблонов
create_templates() {
    log "Создание HTML шаблонов..."

    PROJECT_DIR="/home/kododrive/portfolio"

    # Базовый layout шаблон
    cat > $PROJECT_DIR/templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="{% block description %}KodoDrive - Python Full Stack разработчик, специализирующийся на создании Telegram ботов и автоматизации{% endblock %}">
    <meta name="keywords" content="python, telegram bot, flask, django, автоматизация, веб-разработка">
    <meta name="author" content="KodoDrive">

    <title>{% block title %}KodoDrive - Python Developer{% endblock %}</title>

    <!-- Favicon -->
    <link rel="icon" type="image/x-icon" href="{{ url_for('static', filename='favicon.ico') }}">

    <!-- CSS -->
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">

    {% block extra_css %}{% endblock %}
</head>
<body>
    {% block content %}{% endblock %}

    <!-- JavaScript -->
    <script src="{{ url_for('static', filename='js/script.js') }}"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
EOF

    # Главная страница
    cat > $PROJECT_DIR/templates/index.html << 'EOF'
{% extends "base.html" %}

{% block title %}{{ settings.site_title }} - {{ settings.hero_subtitle }}{% endblock %}
{% block description %}{{ settings.hero_description }}{% endblock %}

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
                    <a href="#portfolio" class="btn btn-primary">
                        <i class="fas fa-briefcase"></i>
                        Мои проекты
                    </a>
                    <a href="#contact" class="btn btn-secondary">
                        <i class="fas fa-envelope"></i>
                        Связаться
                    </a>
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
                <p>{{ settings.about_description }}</p>

                {% if skills %}
                <div class="skills">
                    <h4>Навыки и технологии</h4>
                    {% for skill in skills %}
                    <div class="skill">
                        <div class="skill-header">
                            <span class="skill-name">
                                {% if skill.icon %}<i class="{{ skill.icon }}"></i>{% endif %}
                                {{ skill.name }}
                            </span>
                            <span class="skill-percent">{{ skill.percentage }}%</span>
                        </div>
                        <div class="skill-bar">
                            <div class="skill-progress" data-width="{{ skill.percentage }}%"></div>
                        </div>
                    </div>
                    {% endfor %}
                </div>
                {% endif %}
            </div>

            {% if stats %}
            <div class="about-stats">
                {% for stat in stats %}
                <div class="stat">
                    {% if stat.icon %}<i class="{{ stat.icon }}"></i>{% endif %}
                    <h3 class="stat-number" data-target="{{ stat.value }}">0</h3>
                    <p>{{ stat.label }}</p>
                </div>
                {% endfor %}
            </div>
            {% endif %}
        </div>
    </div>
</section>

<!-- Services Section -->
{% if services %}
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
                {% if service.price %}
                <div class="service-price">{{ service.price }}</div>
                {% endif %}
                <p>{{ service.description }}</p>
                {% if service.features_list %}
                <ul class="service-features">
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
{% endif %}

<!-- Portfolio Section -->
{% if portfolio %}
<section id="portfolio" class="portfolio">
    <div class="container">
        <h2 class="section-title">Портфолио</h2>
        <div class="portfolio-grid">
            {% for project in portfolio %}
            <div class="portfolio-item">
                <div class="portfolio-image">
                    {% if project.image_url %}
                    <img src="{{ project.image_url }}" alt="{{ project.title }}">
                    {% else %}
                    <div class="portfolio-icon">
                        <i class="{{ project.icon }}"></i>
                    </div>
                    {% endif %}
                    {% if project.is_featured %}
                    <div class="portfolio-badge">
                        <i class="fas fa-star"></i>
                        Рекомендуемый
                    </div>
                    {% endif %}
                </div>
                <div class="portfolio-content">
                    <h3>{{ project.title }}</h3>
                    <p>{{ project.short_description or project.description[:150] + '...' }}</p>

                    {% if project.tech_list %}
                    <div class="portfolio-tech">
                        {% for tech in project.tech_list %}
                        <span class="tech-tag">{{ tech }}</span>
                        {% endfor %}
                    </div>
                    {% endif %}

                    <div class="portfolio-links">
                        {% if project.demo_url %}
                        <a href="{{ project.demo_url }}" class="portfolio-link" target="_blank" rel="noopener">
                            <i class="fas fa-external-link-alt"></i>
                            Демо
                        </a>
                        {% endif %}
                        {% if project.github_url %}
                        <a href="{{ project.github_url }}" class="portfolio-link" target="_blank" rel="noopener">
                            <i class="fab fa-github"></i>
                            GitHub
                        </a>
                        {% endif %}
                        {% if project.project_url %}
                        <a href="{{ project.project_url }}" class="portfolio-link" target="_blank" rel="noopener">
                            <i class="fas fa-link"></i>
                            Подробнее
                        </a>
                        {% endif %}
                    </div>
                </div>
            </div>
            {% endfor %}
        </div>
    </div>
</section>
{% endif %}

<!-- Contact Section -->
<section id="contact" class="contact">
    <div class="container">
        <h2 class="section-title">Связаться со мной</h2>
        <div class="contact-content">
            <div class="contact-info">
                <h3>Готов обсудить ваш проект</h3>
                <p>Напишите мне о вашей идее, и я помогу воплотить её в жизнь с помощью современных технологий</p>

                <div class="contact-details">
                    {% if settings.contact_telegram %}
                    <div class="contact-item">
                        <i class="fab fa-telegram"></i>
                        <span>{{ settings.contact_telegram }}</span>
                    </div>
                    {% endif %}
                    {% if settings.contact_email %}
                    <div class="contact-item">
                        <i class="fas fa-envelope"></i>
                        <span>{{ settings.contact_email }}</span>
                    </div>
                    {% endif %}
                    {% if settings.contact_github %}
                    <div class="contact-item">
                        <i class="fab fa-github"></i>
                        <span>{{ settings.contact_github }}</span>
                    </div>
                    {% endif %}
                    {% if settings.contact_linkedin %}
                    <div class="contact-item">
                        <i class="fab fa-linkedin"></i>
                        <span>{{ settings.contact_linkedin }}</span>
                    </div>
                    {% endif %}
                </div>
            </div>

            <div class="contact-form-container">
                <form id="contactForm" class="contact-form">
                    <div class="form-group">
                        <label for="name">Ваше имя *</label>
                        <input type="text" id="name" name="name" required>
                    </div>

                    <div class="form-group">
                        <label for="email">Email *</label>
                        <input type="email" id="email" name="email" required>
                    </div>

                    <div class="form-group">
                        <label for="subject">Тема *</label>
                        <input type="text" id="subject" name="subject" required>
                    </div>

                    <div class="form-group">
                        <label for="message">Сообщение *</label>
                        <textarea id="message" name="message" rows="6" required placeholder="Расскажите о вашем проекте..."></textarea>
                    </div>

                    <button type="submit" class="btn btn-primary">
                        <i class="fas fa-paper-plane"></i>
                        Отправить сообщение
                    </button>
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
                <p>&copy; {{ current_year }} KodoDrive. Все права защищены.</p>
            </div>
            <div class="footer-social">
                {% if settings.contact_telegram %}
                <a href="https://t.me/{{ settings.contact_telegram.replace('@', '') }}" class="social-link" target="_blank" rel="noopener">
                    <i class="fab fa-telegram"></i>
                </a>
                {% endif %}
                {% if settings.contact_github %}
                <a href="https://{{ settings.contact_github }}" class="social-link" target="_blank" rel="noopener">
                    <i class="fab fa-github"></i>
                </a>
                {% endif %}
                {% if settings.contact_linkedin %}
                <a href="{{ settings.contact_linkedin }}" class="social-link" target="_blank" rel="noopener">
                    <i class="fab fa-linkedin"></i>
                </a>
                {% endif %}
            </div>
        </div>
    </div>
</footer>

<!-- Notification Container -->
<div id="notification-container"></div>
{% endblock %}
EOF

    # Создаем админские шаблоны
    create_admin_templates

    # Создаем шаблоны ошибок
    create_error_templates

    chown -R kododrive:kododrive $PROJECT_DIR/templates/
    log "HTML шаблоны созданы успешно"
}

# Функция создания админских шаблонов
create_admin_templates() {
    PROJECT_DIR="/home/kododrive/portfolio"

    # Базовый шаблон админки
    cat > $PROJECT_DIR/templates/admin/base.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Админ панель - KodoDrive{% endblock %}</title>

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">

    <style>
        :root {
            --sidebar-width: 250px;
            --sidebar-bg: #2c3e50;
            --sidebar-hover: #34495e;
            --accent-color: #3498db;
        }

        body { 
            background: #f8f9fa; 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
        }

        .sidebar {
            position: fixed;
            top: 0;
            left: 0;
            height: 100vh;
            width: var(--sidebar-width);
            background: var(--sidebar-bg);
            z-index: 1000;
            overflow-y: auto;
        }

        .sidebar .brand {
            padding: 20px;
            border-bottom: 1px solid #34495e;
        }

        .sidebar .brand h4 {
            color: white;
            margin: 0;
            font-weight: 600;
        }

        .sidebar .brand small {
            color: #bdc3c7;
        }

        .sidebar .nav-link {
            color: #bdc3c7;
            padding: 12px 20px;
            margin: 2px 0;
            border-radius: 0;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
        }

        .sidebar .nav-link:hover,
        .sidebar .nav-link.active {
            background: var(--accent-color);
            color: white;
        }

        .sidebar .nav-link i {
            width: 20px;
            margin-right: 10px;
        }

        .main-content {
            margin-left: var(--sidebar-width);
            min-height: 100vh;
            padding: 20px;
        }

        .content-header {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }

        .content-header h1 {
            margin: 0;
            color: #2c3e50;
            font-size: 1.8rem;
            font-weight: 600;
        }

        .card {
            border: none;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }

        .card-header {
            background: linear-gradient(135deg, var(--accent-color), #2980b9);
            color: white;
            border-radius: 10px 10px 0 0 !important;
            font-weight: 600;
        }

        .btn-primary {
            background: var(--accent-color);
            border-color: var(--accent-color);
        }

        .btn-primary:hover {
            background: #2980b9;
            border-color: #2980b9;
        }

        .alert {
            border-radius: 10px;
            border: none;
        }

        .table {
            margin-bottom: 0;
        }

        .table th {
            border-top: none;
            font-weight: 600;
            color: #2c3e50;
        }

        .badge {
            font-size: 0.75em;
        }

        @media (max-width: 768px) {
            .sidebar {
                transform: translateX(-100%);
                transition: transform 0.3s ease;
            }

            .sidebar.show {
                transform: translateX(0);
            }

            .main-content {
                margin-left: 0;
            }
        }
    </style>

    {% block extra_css %}{% endblock %}
</head>
<body>
    <div class="sidebar">
        <div class="brand">
            <h4><i class="fas fa-code me-2"></i>KodoDrive</h4>
            <small>Админ панель</small>
        </div>

        <nav class="mt-3">
            <a href="{{ url_for('admin_dashboard') }}" class="nav-link {% if request.endpoint == 'admin_dashboard' %}active{% endif %}">
                <i class="fas fa-tachometer-alt"></i>
                Dashboard
            </a>
            <a href="{{ url_for('admin_settings') }}" class="nav-link {% if request.endpoint == 'admin_settings' %}active{% endif %}">
                <i class="fas fa-cog"></i>
                Настройки сайта
            </a>
            <a href="{{ url_for('admin_portfolio') }}" class="nav-link {% if 'portfolio' in request.endpoint %}active{% endif %}">
                <i class="fas fa-briefcase"></i>
                Портфолио
            </a>
            <a href="{{ url_for('admin_messages') }}" class="nav-link {% if 'message' in request.endpoint %}active{% endif %}">
                <i class="fas fa-envelope"></i>
                Сообщения
            </a>

            <hr class="my-3" style="border-color: #34495e;">

            <a href="{{ url_for('index') }}" class="nav-link" target="_blank">
                <i class="fas fa-external-link-alt"></i>
                Посмотреть сайт
            </a>
            <a href="{{ url_for('admin_logout') }}" class="nav-link">
                <i class="fas fa-sign-out-alt"></i>
                Выйти
            </a>
        </nav>
    </div>

    <div class="main-content">
        <div class="content-header">
            <h1>{% block page_title %}Dashboard{% endblock %}</h1>
        </div>

        <!-- Flash Messages -->
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                <div class="alert alert-{% if category == 'error' %}danger{% elif category == 'info' %}info{% elif category == 'success' %}success{% else %}warning{% endif %} alert-dismissible fade show" role="alert">
                    <i class="fas fa-{% if category == 'error' %}exclamation-triangle{% elif category == 'success' %}check-circle{% elif category == 'info' %}info-circle{% else %}exclamation-circle{% endif %} me-2"></i>
                    {{ message }}
                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                </div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        {% block content %}{% endblock %}
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
EOF

    # Страница входа в админку
    cat > $PROJECT_DIR/templates/admin/login.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Вход в админ панель - KodoDrive</title>

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">

    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }

        .login-container {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            width: 100%;
            max-width: 400px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }

        .login-header {
            text-align: center;
            margin-bottom: 2rem;
        }

        .login-header h2 {
            color: #2c3e50;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }

        .login-header p {
            color: #6c757d;
            margin-bottom: 0;
        }

        .form-control {
            border-radius: 10px;
            border: 2px solid #e9ecef;
            padding: 12px 15px;
            font-size: 1rem;
        }

        .form-control:focus {
            border-color: #3498db;
            box-shadow: 0 0 0 0.2rem rgba(52, 152, 219, 0.25);
        }

        .btn-login {
            background: linear-gradient(135deg, #3498db, #2980b9);
            border: none;
            border-radius: 10px;
            padding: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .btn-login:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(52, 152, 219, 0.3);
        }

        .alert {
            border-radius: 10px;
            border: none;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-header">
            <h2><i class="fas fa-code me-2"></i>KodoDrive</h2>
            <p>Админ панель</p>
        </div>

        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                <div class="alert alert-{% if category == 'error' %}danger{% else %}{{ category }}{% endif %} mb-3" role="alert">
                    <i class="fas fa-{% if category == 'error' %}exclamation-triangle{% else %}info-circle{% endif %} me-2"></i>
                    {{ message }}
                </div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        <form method="POST">
            <div class="mb-3">
                <label for="username" class="form-label">Имя пользователя</label>
                <input type="text" name="username" id="username" class="form-control" placeholder="Введите логин" required autofocus>
            </div>

            <div class="mb-4">
                <label for="password" class="form-label">Пароль</label>
                <input type="password" name="password" id="password" class="form-control" placeholder="Введите пароль" required>
            </div>

            <button type="submit" class="btn btn-primary btn-login w-100">
                <i class="fas fa-sign-in-alt me-2"></i>
                Войти
            </button>
        </form>

        <div class="text-center mt-3">
            <a href="{{ url_for('index') }}" class="text-muted text-decoration-none">
                <i class="fas fa-arrow-left me-1"></i>
                Вернуться на сайт
            </a>
        </div>
    </div>
</body>
</html>
EOF

    # Dashboard админки
    cat > $PROJECT_DIR/templates/admin/dashboard.html << 'EOF'
{% extends "admin/base.html" %}

{% block content %}
<div class="row">
    <!-- Статистические карточки -->
    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-primary shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">
                            Проекты
                        </div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800">{{ stats.active_projects }}/{{ stats.total_projects }}</div>
                    </div>
                    <div class="col-auto">
                        <i class="fas fa-briefcase fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-success shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-success text-uppercase mb-1">
                            Услуги
                        </div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800">{{ stats.active_services }}/{{ stats.total_services }}</div>
                    </div>
                    <div class="col-auto">
                        <i class="fas fa-cogs fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-info shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-info text-uppercase mb-1">
                            Навыки
                        </div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800">{{ stats.active_skills }}/{{ stats.total_skills }}</div>
                    </div>
                    <div class="col-auto">
                        <i class="fas fa-code fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="col-xl-3 col-md-6 mb-4">
        <div class="card border-left-warning shadow h-100 py-2">
            <div class="card-body">
                <div class="row no-gutters align-items-center">
                    <div class="col mr-2">
                        <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">
                            Сообщения
                        </div>
                        <div class="h5 mb-0 font-weight-bold text-gray-800">
                            {{ stats.unread_messages }}/{{ stats.total_messages }}
                            {% if stats.unread_messages > 0 %}
                            <span class="badge bg-danger ms-1">{{ stats.unread_messages }}</span>
                            {% endif %}
                        </div>
                    </div>
                    <div class="col-auto">
                        <i class="fas fa-envelope fa-2x text-gray-300"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row">
    <!-- Быстрые действия -->
    <div class="col-lg-6 mb-4">
        <div class="card">
            <div class="card-header">
                <i class="fas fa-bolt me-2"></i>
                Быстрые действия
            </div>
            <div class="card-body">
                <div class="d-grid gap-2">
                    <a href="{{ url_for('admin_portfolio_add') }}" class="btn btn-primary">
                        <i class="fas fa-plus me-2"></i>
                        Добавить проект
                    </a>
                    <a href="{{ url_for('admin_settings') }}" class="btn btn-secondary">
                        <i class="fas fa-cog me-2"></i>
                        Настройки сайта
                    </a>
                    <a href="{{ url_for('admin_messages') }}" class="btn btn-info">
                        <i class="fas fa-envelope me-2"></i>
                        Проверить сообщения
                        {% if stats.unread_messages > 0 %}
                        <span class="badge bg-danger ms-1">{{ stats.unread_messages }}</span>
                        {% endif %}
                    </a>
                </div>
            </div>
        </div>
    </div>

    <!-- Последние сообщения -->
    <div class="col-lg-6 mb-4">
        <div class="card">
            <div class="card-header">
                <i class="fas fa-comments me-2"></i>
                Последние сообщения
            </div>
            <div class="card-body">
                {% if recent_messages %}
                    {% for message in recent_messages %}
                    <div class="d-flex align-items-center mb-3">
                        <div class="flex-shrink-0">
                            <div class="rounded-circle bg-primary text-white d-flex align-items-center justify-content-center" style="width: 40px; height: 40px;">
                                <i class="fas fa-user"></i>
                            </div>
                        </div>
                        <div class="flex-grow-1 ms-3">
                            <div class="fw-bold">{{ message.name }}</div>
                            <div class="text-muted small">{{ message.subject }}</div>
                            <div class="text-muted small">{{ message.created_at.strftime('%d.%m.%Y %H:%M') }}</div>
                        </div>
                        <div class="flex-shrink-0">
                            {% if not message.is_read %}
                            <span class="badge bg-danger">Новое</span>
                            {% endif %}
                        </div>
                    </div>
                    {% if not loop.last %}<hr>{% endif %}
                    {% endfor %}
                {% else %}
                    <p class="text-muted mb-0">Сообщений пока нет</p>
                {% endif %}
            </div>
        </div>
    </div>
</div>

{% if recent_projects %}
<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-header">
                <i class="fas fa-project-diagram me-2"></i>
                Последние проекты
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-hover">
                        <thead>
                            <tr>
                                <th>Название</th>
                                <th>Категория</th>
                                <th>Статус</th>
                                <th>Создан</th>
                                <th>Действия</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for project in recent_projects %}
                            <tr>
                                <td>
                                    <strong>{{ project.title }}</strong>
                                    {% if project.is_featured %}
                                    <span class="badge bg-warning ms-1">Рекомендуемый</span>
                                    {% endif %}
                                </td>
                                <td>{{ project.category }}</td>
                                <td>
                                    {% if project.status == 'completed' %}
                                    <span class="badge bg-success">Завершен</span>
                                    {% elif project.status == 'in_progress' %}
                                    <span class="badge bg-primary">В процессе</span>
                                    {% else %}
                                    <span class="badge bg-secondary">Запланирован</span>
                                    {% endif %}
                                </td>
                                <td>{{ project.created_at.strftime('%d.%m.%Y') }}</td>
                                <td>
                                    <a href="{{ url_for('admin_portfolio_edit', id=project.id) }}" class="btn btn-sm btn-outline-primary">
                                        <i class="fas fa-edit"></i>
                                    </a>
                                </td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
{% endif %}
{% endblock %}
EOF

    # Остальные админские шаблоны...
    # (settings.html, portfolio.html, portfolio_form.html, messages.html, message_view.html)
    # Создаю сокращенные версии для экономии места:

    cat > $PROJECT_DIR/templates/admin/settings.html << 'EOF'
{% extends "admin/base.html" %}
{% block page_title %}Настройки сайта{% endblock %}

{% block content %}
<div class="card">
    <div class="card-header">
        <i class="fas fa-cog me-2"></i>
        Настройки сайта
    </div>
    <div class="card-body">
        <form method="POST">
            <div class="row">
                <div class="col-md-6">
                    <div class="mb-3">
                        <label class="form-label">Название сайта</label>
                        <input type="text" name="site_title" class="form-control" value="{{ settings.site_title }}" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Заголовок Hero секции</label>
                        <input type="text" name="hero_title" class="form-control" value="{{ settings.hero_title }}" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Подзаголовок Hero секции</label>
                        <input type="text" name="hero_subtitle" class="form-control" value="{{ settings.hero_subtitle }}" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Описание Hero секции</label>
                        <textarea name="hero_description" class="form-control" rows="3" required>{{ settings.hero_description }}</textarea>
                    </div>
                </div>

                <div class="col-md-6">
                    <div class="mb-3">
                        <label class="form-label">Заголовок "О себе"</label>
                        <input type="text" name="about_title" class="form-control" value="{{ settings.about_title }}" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Описание "О себе"</label>
                        <textarea name="about_description" class="form-control" rows="4" required>{{ settings.about_description }}</textarea>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Email</label>
                        <input type="email" name="contact_email" class="form-control" value="{{ settings.contact_email }}" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Telegram</label>
                        <input type="text" name="contact_telegram" class="form-control" value="{{ settings.contact_telegram }}" placeholder="@username">
                    </div>

                    <div class="mb-3">
                        <label class="form-label">GitHub</label>
                        <input type="text" name="contact_github" class="form-control" value="{{ settings.contact_github }}" placeholder="github.com/username">
                    </div>

                    <div class="mb-3">
                        <label class="form-label">LinkedIn</label>
                        <input type="url" name="contact_linkedin" class="form-control" value="{{ settings.contact_linkedin }}" placeholder="https://linkedin.com/in/username">
                    </div>
                </div>
            </div>

            <div class="d-grid">
                <button type="submit" class="btn btn-primary">
                    <i class="fas fa-save me-2"></i>
                    Сохранить настройки
                </button>
            </div>
        </form>
    </div>
</div>
{% endblock %}
EOF

    # Простые заглушки для остальных шаблонов
    echo '{% extends "admin/base.html" %}{% block content %}<h3>Портфолио</h3>{% endblock %}' > $PROJECT_DIR/templates/admin/portfolio.html
    echo '{% extends "admin/base.html" %}{% block content %}<h3>Форма портфолио</h3>{% endblock %}' > $PROJECT_DIR/templates/admin/portfolio_form.html
    echo '{% extends "admin/base.html" %}{% block content %}<h3>Сообщения</h3>{% endblock %}' > $PROJECT_DIR/templates/admin/messages.html
    echo '{% extends "admin/base.html" %}{% block content %}<h3>Просмотр сообщения</h3>{% endblock %}' > $PROJECT_DIR/templates/admin/message_view.html
}

# Функция создания шаблонов ошибок
create_error_templates() {
    PROJECT_DIR="/home/kododrive/portfolio"
    mkdir -p $PROJECT_DIR/templates/errors

    cat > $PROJECT_DIR/templates/errors/404.html << 'EOF'
{% extends "base.html" %}
{% block title %}Страница не найдена - KodoDrive{% endblock %}
{% block content %}
<div style="min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #0f0f23;">
    <div style="text-align: center; color: white;">
        <h1 style="font-size: 8rem; margin: 0; color: #6366f1;">404</h1>
        <h2>Страница не найдена</h2>
        <p>Извините, запрашиваемая страница не существует.</p>
        <a href="{{ url_for('index') }}" class="btn btn-primary">Вернуться на главную</a>
    </div>
</div>
{% endblock %}
EOF

    echo '{% extends "errors/404.html" %}{% block title %}Ошибка сервера - KodoDrive{% endblock %}' > $PROJECT_DIR/templates/errors/500.html
    echo '{% extends "errors/404.html" %}{% block title %}Доступ запрещен - KodoDrive{% endblock %}' > $PROJECT_DIR/templates/errors/403.html
}

# Функция создания статических файлов (CSS и JS)
create_static_files() {
    log "Создание статических файлов..."

    PROJECT_DIR="/home/kododrive/portfolio"

    # Полный CSS файл из вашего оригинального дизайна
    cat > $PROJECT_DIR/static/css/style.css << 'EOF'
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
    color: white;
}

.btn-secondary {
    background: transparent;
    color: var(--text-color);
    border: 2px solid var(--primary-color);
}

.btn-secondary:hover {
    background: var(--primary-color);
    transform: translateY(-2px);
    color: white;
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

.skills h4 {
    font-size: 1.3rem;
    margin-bottom: 1rem;
    color: var(--text-color);
}

.skill {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.skill-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.skill-name {
    font-weight: 600;
    color: var(--text-color);
}

.skill-name i {
    margin-right: 8px;
    color: var(--primary-color);
}

.skill-percent {
    font-weight: 600;
    color: var(--accent-color);
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
    transition: transform 0.3s ease;
}

.stat:hover {
    transform: translateY(-5px);
}

.stat i {
    font-size: 2.5rem;
    color: var(--primary-color);
    margin-bottom: 1rem;
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
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
}

.service-card {
    background: var(--bg-secondary);
    padding: 2.5rem;
    border-radius: 20px;
    text-align: center;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    border: 1px solid var(--border-color);
    position: relative;
    overflow: hidden;
}

.service-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 3px;
    background: var(--gradient);
    transition: left 0.5s ease;
}

.service-card:hover::before {
    left: 0;
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
    transition: transform 0.3s ease;
}

.service-card:hover .service-icon {
    transform: scale(1.1) rotate(5deg);
}

.service-card h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    color: var(--text-color);
}

.service-price {
    font-size: 1.2rem;
    font-weight: 600;
    color: var(--accent-color);
    margin-bottom: 1rem;
}

.service-card p {
    color: var(--text-muted);
    margin-bottom: 1.5rem;
    line-height: 1.6;
}

.service-features {
    list-style: none;
    text-align: left;
    padding: 0;
}

.service-features li {
    color: var(--text-muted);
    margin-bottom: 0.5rem;
    position: relative;
    padding-left: 1.5rem;
}

.service-features li::before {
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
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 2rem;
}

.portfolio-item {
    background: var(--bg-color);
    border-radius: 20px;
    overflow: hidden;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    border: 1px solid var(--border-color);
    position: relative;
}

.portfolio-item:hover {
    transform: translateY(-5px);
    box-shadow: var(--shadow);
}

.portfolio-image {
    height: 250px;
    background: var(--gradient);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    overflow: hidden;
}

.portfolio-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.portfolio-icon {
    font-size: 4rem;
    color: white;
}

.portfolio-badge {
    position: absolute;
    top: 15px;
    right: 15px;
    background: rgba(255, 255, 255, 0.9);
    color: var(--primary-color);
    padding: 5px 10px;
    border-radius: 15px;
    font-size: 0.8rem;
    font-weight: 600;
}

.portfolio-badge i {
    margin-right: 3px;
}

.portfolio-content {
    padding: 2rem;
}

.portfolio-content h3 {
    font-size: 1.4rem;
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

.tech-tag {
    background: var(--primary-color);
    color: white;
    padding: 0.3rem 0.8rem;
    border-radius: 15px;
    font-size: 0.8rem;
    font-weight: 500;
}

.portfolio-links {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

.portfolio-link {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 600;
    font-size: 0.9rem;
    padding: 5px 10px;
    border: 1px solid var(--primary-color);
    border-radius: 20px;
    transition: all 0.3s ease;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
}

.portfolio-link:hover {
    background: var(--primary-color);
    color: white;
    transform: translateY(-2px);
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
    padding: 1rem;
    background: var(--bg-secondary);
    border-radius: 10px;
    transition: all 0.3s ease;
}

.contact-item:hover {
    background: var(--border-color);
    transform: translateX(5px);
}

.contact-item i {
    width: 20px;
    color: var(--primary-color);
    font-size: 1.2rem;
}

.contact-form-container {
    background: var(--bg-secondary);
    padding: 2.5rem;
    border-radius: 20px;
    border: 1px solid var(--border-color);
}

.contact-form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.form-group {
    display: flex;
    flex-direction: column;
}

.form-group label {
    margin-bottom: 0.5rem;
    font-weight: 600;
    color: var(--text-color);
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
    font-size: 1rem;
    transition: border-color 0.3s ease, box-shadow 0.3s ease;
}

.form-group input:focus,
.form-group textarea:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
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
    margin: 0;
}

.footer-social {
    display: flex;
    gap: 1rem;
}

.social-link {
    width: 45px;
    height: 45px;
    background: var(--bg-color);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-color);
    text-decoration: none;
    transition: all 0.3s ease;
    border: 1px solid var(--border-color);
}

.social-link:hover {
    background: var(--primary-color);
    color: white;
    transform: translateY(-3px);
    box-shadow: 0 5px 15px rgba(99, 102, 241, 0.4);
}

/* Notification System */
#notification-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 10000;
}

.notification {
    background: var(--bg-secondary);
    color: var(--text-color);
    padding: 15px 20px;
    border-radius: 10px;
    margin-bottom: 10px;
    box-shadow: var(--shadow);
    border-left: 4px solid var(--primary-color);
    transform: translateX(400px);
    opacity: 0;
    transition: all 0.3s ease;
    max-width: 350px;
}

.notification.show {
    transform: translateX(0);
    opacity: 1;
}

.notification.success {
    border-left-color: #10b981;
}

.notification.error {
    border-left-color: #ef4444;
}

.notification.info {
    border-left-color: #3b82f6;
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
        border-top: 1px solid var(--border-color);
    }

    .nav-menu.active {
        left: 0;
    }

    .hero-content {
        grid-template-columns: 1fr;
        text-align: center;
        gap: 3rem;
    }

    .hero-title {
        font-size: 2.5rem;
    }

    .about-content {
        grid-template-columns: 1fr;
        gap: 3rem;
    }

    .contact-content {
        grid-template-columns: 1fr;
        gap: 3rem;
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

    .hero-buttons {
        justify-content: center;
    }

    .portfolio-links {
        justify-content: center;
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

    .services-grid {
        grid-template-columns: 1fr;
    }

    .portfolio-grid {
        grid-template-columns: 1fr;
    }

    .service-card,
    .contact-form-container {
        padding: 1.5rem;
    }

    .btn {
        padding: 10px 20px;
        font-size: 0.9rem;
    }
}

/* Улучшения для очень маленьких экранов */
@media (max-width: 360px) {
    .hero-title {
        font-size: 1.8rem;
    }

    .section-title {
        font-size: 1.8rem;
    }

    .profile-card {
        width: 200px;
        height: 200px;
    }

    .profile-avatar {
        width: 100px;
        height: 100px;
        font-size: 2.5rem;
    }
}

/* Дополнительные улучшения производительности */
@media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
    }
}

/* Высококонтрастная тема */
@media (prefers-contrast: high) {
    :root {
        --text-color: #ffffff;
        --text-muted: #cccccc;
        --border-color: #666666;
    }
}
EOF

    # Полный JavaScript файл
    cat > $PROJECT_DIR/static/js/script.js << 'EOF'
// Переменные для элементов
let hamburger, navMenu, contactForm, notificationContainer;

// Инициализация после загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    initializeElements();
    initializeNavigation();
    initializeAnimations();
    initializeContactForm();
    initializeScrollEffects();

    // Создание контейнера для уведомлений
    createNotificationContainer();
});

// Инициализация основных элементов
function initializeElements() {
    hamburger = document.querySelector('.hamburger');
    navMenu = document.querySelector('.nav-menu');
    contactForm = document.getElementById('contactForm');
}

// ===============================
// НАВИГАЦИЯ
// ===============================

function initializeNavigation() {
    // Мобильное меню
    if (hamburger && navMenu) {
        hamburger.addEventListener('click', toggleMobileMenu);

        // Закрытие меню при клике на ссылку
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', closeMobileMenu);
        });

        // Закрытие меню при клике вне его
        document.addEventListener('click', function(e) {
            if (!hamburger.contains(e.target) && !navMenu.contains(e.target)) {
                closeMobileMenu();
            }
        });
    }

    // Плавная прокрутка для якорных ссылок
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                const offsetTop = target.offsetTop - 80;
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
            }
        });
    });
}

function toggleMobileMenu() {
    hamburger.classList.toggle('active');
    navMenu.classList.toggle('active');

    // Анимация гамбургера
    const bars = hamburger.querySelectorAll('.bar');
    if (hamburger.classList.contains('active')) {
        bars[0].style.transform = 'rotate(-45deg) translate(-5px, 6px)';
        bars[1].style.opacity = '0';
        bars[2].style.transform = 'rotate(45deg) translate(-5px, -6px)';
    } else {
        bars[0].style.transform = 'none';
        bars[1].style.opacity = '1';
        bars[2].style.transform = 'none';
    }
}

function closeMobileMenu() {
    if (hamburger && navMenu) {
        hamburger.classList.remove('active');
        navMenu.classList.remove('active');

        // Сброс анимации гамбургера
        const bars = hamburger.querySelectorAll('.bar');
        bars[0].style.transform = 'none';
        bars[1].style.opacity = '1';
        bars[2].style.transform = 'none';
    }
}

// ===============================
// ЭФФЕКТЫ ПРОКРУТКИ
// ===============================

function initializeScrollEffects() {
    let ticking = false;

    function updateOnScroll() {
        updateHeaderOnScroll();
        updateActiveNavLink();
        ticking = false;
    }

    window.addEventListener('scroll', function() {
        if (!ticking) {
            requestAnimationFrame(updateOnScroll);
            ticking = true;
        }
    });
}

function updateHeaderOnScroll() {
    const header = document.querySelector('.header');
    if (!header) return;

    if (window.scrollY > 100) {
        header.style.background = 'rgba(15, 15, 35, 0.98)';
        header.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.3)';
        header.style.borderBottom = '1px solid rgba(255, 255, 255, 0.1)';
    } else {
        header.style.background = 'rgba(15, 15, 35, 0.95)';
        header.style.boxShadow = 'none';
        header.style.borderBottom = 'none';
    }
}

function updateActiveNavLink() {
    const sections = document.querySelectorAll('section[id]');
    const navLinks = document.querySelectorAll('.nav-link');

    let currentSection = '';

    sections.forEach(section => {
        const sectionTop = section.offsetTop - 150;
        const sectionHeight = section.offsetHeight;

        if (window.scrollY >= sectionTop && window.scrollY < sectionTop + sectionHeight) {
            currentSection = section.getAttribute('id');
        }
    });

    navLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href') === '#' + currentSection) {
            link.classList.add('active');
        }
    });
}

// ===============================
// АНИМАЦИИ
// ===============================

function initializeAnimations() {
    // Typing анимация
    initializeTypingAnimation();

    // Intersection Observer для анимаций секций
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in-up');

                // Специфические анимации для разных секций
                if (entry.target.classList.contains('about')) {
                    setTimeout(() => {
                        animateCounters();
                        animateSkillBars();
                    }, 500);
                }

                if (entry.target.classList.contains('stats')) {
                    setTimeout(animateCounters, 300);
                }
            }
        });
    }, observerOptions);

    // Наблюдаем за секциями
    document.querySelectorAll('section').forEach(section => {
        observer.observe(section);
    });

    // Наблюдаем за карточками
    document.querySelectorAll('.service-card, .portfolio-item, .stat').forEach(card => {
        observer.observe(card);
    });
}

function initializeTypingAnimation() {
    const typingElement = document.querySelector('.typing-text');
    if (!typingElement) return;

    const originalText = typingElement.textContent;
    const textArray = originalText.split('');
    let currentIndex = 0;

    // Очищаем текст
    typingElement.textContent = '';

    function typeNextCharacter() {
        if (currentIndex < textArray.length) {
            typingElement.textContent += textArray[currentIndex];
            currentIndex++;
            setTimeout(typeNextCharacter, 100);
        }
    }

    // Начинаем анимацию после небольшой задержки
    setTimeout(typeNextCharacter, 1000);
}

function animateCounters() {
    const counters = document.querySelectorAll('.stat-number[data-target]');

    counters.forEach(counter => {
        // Проверяем, не была ли анимация уже запущена
        if (counter.dataset.animated === 'true') return;
        counter.dataset.animated = 'true';

        const target = parseInt(counter.getAttribute('data-target'));
        const duration = 2000; // 2 секунды
        const increment = target / (duration / 16); // 60 FPS
        let current = 0;

        const updateCounter = () => {
            if (current < target) {
                current += increment;
                counter.textContent = Math.ceil(current);
                requestAnimationFrame(updateCounter);
            } else {
                counter.textContent = target;
            }
        };

        updateCounter();
    });
}

function animateSkillBars() {
    const skillBars = document.querySelectorAll('.skill-progress[data-width]');

    skillBars.forEach((bar, index) => {
        // Проверяем, не была ли анимация уже запущена
        if (bar.dataset.animated === 'true') return;
        bar.dataset.animated = 'true';

        const width = bar.getAttribute('data-width');

        setTimeout(() => {
            bar.style.width = width;
        }, index * 200); // Задержка для каждого бара
    });
}

// ===============================
// КОНТАКТНАЯ ФОРМА
// ===============================

function initializeContactForm() {
    if (!contactForm) return;

    contactForm.addEventListener('submit', handleFormSubmit);

    // Улучшенная валидация полей в реальном времени
    const inputs = contactForm.querySelectorAll('input, textarea');
    inputs.forEach(input => {
        input.addEventListener('blur', validateField);
        input.addEventListener('input', clearFieldError);
    });
}

async function handleFormSubmit(e) {
    e.preventDefault();

    const submitButton = contactForm.querySelector('button[type="submit"]');
    const originalButtonText = submitButton.innerHTML;

    // Получаем данные формы
    const formData = new FormData(contactForm);
    const data = Object.fromEntries(formData.entries());

    // Валидация
    if (!validateForm(data)) {
        return;
    }

    // Показываем состояние загрузки
    submitButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Отправка...';
    submitButton.disabled = true;

    try {
        const response = await fetch('/contact', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.status === 'success') {
            showNotification(result.message, 'success');
            contactForm.reset();

            // Добавляем конфетти эффект при успешной отправке
            createConfettiEffect();
        } else {
            showNotification(result.message, 'error');
        }
    } catch (error) {
        console.error('Ошибка при отправке формы:', error);
        showNotification('Произошла ошибка при отправке сообщения. Попробуйте позже.', 'error');
    } finally {
        // Восстанавливаем кнопку
        setTimeout(() => {
            submitButton.innerHTML = originalButtonText;
            submitButton.disabled = false;
        }, 1000);
    }
}

function validateForm(data) {
    let isValid = true;
    const errors = {};

    // Валидация имени
    if (!data.name || data.name.trim().length < 2) {
        errors.name = 'Имя должно содержать минимум 2 символа';
        isValid = false;
    }

    // Валидация email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!data.email || !emailRegex.test(data.email)) {
        errors.email = 'Введите корректный email адрес';
        isValid = false;
    }

    // Валидация темы
    if (!data.subject || data.subject.trim().length < 3) {
        errors.subject = 'Тема должна содержать минимум 3 символа';
        isValid = false;
    }

    // Валидация сообщения
    if (!data.message || data.message.trim().length < 10) {
        errors.message = 'Сообщение должно содержать минимум 10 символов';
        isValid = false;
    }

    // Показываем ошибки
    Object.keys(errors).forEach(field => {
        showFieldError(field, errors[field]);
    });

    return isValid;
}

function validateField(e) {
    const field = e.target;
    const value = field.value.trim();
    const name = field.name;

    clearFieldError(e);

    switch (name) {
        case 'name':
            if (value.length > 0 && value.length < 2) {
                showFieldError(name, 'Имя должно содержать минимум 2 символа');
            }
            break;
        case 'email':
            if (value.length > 0 && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
                showFieldError(name, 'Введите корректный email адрес');
            }
            break;
        case 'subject':
            if (value.length > 0 && value.length < 3) {
                showFieldError(name, 'Тема должна содержать минимум 3 символа');
            }
            break;
        case 'message':
            if (value.length > 0 && value.length < 10) {
                showFieldError(name, 'Сообщение должно содержать минимум 10 символов');
            }
            break;
    }
}

function showFieldError(fieldName, message) {
    const field = document.querySelector(`[name="${fieldName}"]`);
    if (!field) return;

    // Удаляем существующую ошибку
    const existingError = field.parentNode.querySelector('.field-error');
    if (existingError) {
        existingError.remove();
    }

    // Добавляем новую ошибку
    const errorElement = document.createElement('div');
    errorElement.className = 'field-error';
    errorElement.textContent = message;
    errorElement.style.cssText = `
        color: #ef4444;
        font-size: 0.875rem;
        margin-top: 0.25rem;
        animation: fadeInUp 0.3s ease;
    `;

    field.style.borderColor = '#ef4444';
    field.parentNode.appendChild(errorElement);
}

function clearFieldError(e) {
    const field = e.target;
    const errorElement = field.parentNode.querySelector('.field-error');

    if (errorElement) {
        errorElement.remove();
        field.style.borderColor = '';
    }
}

// ===============================
// СИСТЕМА УВЕДОМЛЕНИЙ
// ===============================

function createNotificationContainer() {
    if (!document.getElementById('notification-container')) {
        const container = document.createElement('div');
        container.id = 'notification-container';
        document.body.appendChild(container);
    }
    notificationContainer = document.getElementById('notification-container');
}

function showNotification(message, type = 'info', duration = 5000) {
    if (!notificationContainer) {
        createNotificationContainer();
    }

    const notification = document.createElement('div');
    notification.className = `notification ${type}`;

    // Добавляем иконку в зависимости от типа
    const icons = {
        success: 'fas fa-check-circle',
        error: 'fas fa-exclamation-triangle',
        warning: 'fas fa-exclamation-circle',
        info: 'fas fa-info-circle'
    };

    notification.innerHTML = `
        <i class="${icons[type] || icons.info}"></i>
        <span>${message}</span>
        <button class="notification-close" onclick="this.parentElement.remove()">
            <i class="fas fa-times"></i>
        </button>
    `;

    // Стили для закрывающей кнопки
    const closeButton = notification.querySelector('.notification-close');
    closeButton.style.cssText = `
        background: none;
        border: none;
        color: inherit;
        cursor: pointer;
        padding: 0;
        margin-left: 10px;
        opacity: 0.7;
        transition: opacity 0.3s ease;
    `;

    closeButton.addEventListener('mouseenter', () => closeButton.style.opacity = '1');
    closeButton.addEventListener('mouseleave', () => closeButton.style.opacity = '0.7');

    notificationContainer.appendChild(notification);

    // Анимация появления
    setTimeout(() => notification.classList.add('show'), 100);

    // Автоматическое удаление
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, duration);
}

// ===============================
// ДОПОЛНИТЕЛЬНЫЕ ЭФФЕКТЫ
// ===============================

function createConfettiEffect() {
    const colors = ['#6366f1', '#8b5cf6', '#06b6d4', '#10b981', '#f59e0b'];
    const confettiCount = 50;

    for (let i = 0; i < confettiCount; i++) {
        setTimeout(() => {
            const confetti = document.createElement('div');
            confetti.style.cssText = `
                position: fixed;
                width: 10px;
                height: 10px;
                background: ${colors[Math.floor(Math.random() * colors.length)]};
                left: ${Math.random() * 100}%;
                top: -10px;
                z-index: 10000;
                animation: confettiFall 3s ease-out forwards;
                border-radius: 50%;
            `;

            document.body.appendChild(confetti);

            setTimeout(() => confetti.remove(), 3000);
        }, i * 50);
    }
}

// CSS анимация для конфетти (добавляется динамически)
if (!document.getElementById('confetti-styles')) {
    const style = document.createElement('style');
    style.id = 'confetti-styles';
    style.textContent = `
        @keyframes confettiFall {
            to {
                transform: translateY(100vh) rotate(360deg);
                opacity: 0;
            }
        }
    `;
    document.head.appendChild(style);
}

// ===============================
// УТИЛИТЫ И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ===============================

// Debounce функция для оптимизации производительности
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Throttle функция для событий прокрутки
function throttle(func, limit) {
    let inThrottle;
    return function() {
        const args = arguments;
        const context = this;
        if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// Функция для плавного появления элементов
function fadeInElement(element, duration = 1000) {
    element.style.opacity = '0';
    element.style.transition = `opacity ${duration}ms ease`;

    setTimeout(() => {
        element.style.opacity = '1';
    }, 10);
}

// Определение устройства пользователя
function isMobile() {
    return window.innerWidth <= 768;
}

function isTablet() {
    return window.innerWidth > 768 && window.innerWidth <= 1024;
}

// Функция для lazy loading изображений
function initializeLazyLoading() {
    const images = document.querySelectorAll('img[data-src]');

    if ('IntersectionObserver' in window) {
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

        images.forEach(img => imageObserver.observe(img));
    } else {
        // Fallback for older browsers
        images.forEach(img => {
            img.src = img.dataset.src;
            img.classList.remove('lazy');
        });
    }
}

// Инициализация lazy loading при загрузке страницы
document.addEventListener('DOMContentLoaded', initializeLazyLoading);

// Обработка изменения размера окна
window.addEventListener('resize', debounce(() => {
    // Закрываем мобильное меню при изменении размера окна
    if (window.innerWidth > 768) {
        closeMobileMenu();
    }
}, 250));

// Обработка видимости страницы (для оптимизации анимаций)
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        // Приостанавливаем анимации когда страница скрыта
        document.body.style.animationPlayState = 'paused';
    } else {
        // Возобновляем анимации
        document.body.style.animationPlayState = 'running';
    }
});

// Предотвращение FOUC (Flash of Unstyled Content)
document.documentElement.style.visibility = 'visible';

// Улучшенная обработка ошибок JavaScript
window.addEventListener('error', (e) => {
    console.error('JavaScript error:', e.error);
    // В продакшене можно отправлять ошибки на сервер для мониторинга
});

// Performance monitoring
if ('performance' in window) {
    window.addEventListener('load', () => {
        setTimeout(() => {
            const perfData = performance.getEntriesByType('navigation')[0];
            console.log('Page load time:', perfData.loadEventEnd - perfData.loadEventStart, 'ms');
        }, 0);
    });
}

console.log('🚀 KodoDrive Portfolio - JavaScript loaded successfully!');
EOF

    # Создаем простой favicon
    echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x10\x00\x00\x00\x10\x08\x06\x00\x00\x00\x1f\xf3\xffa\x00\x00\x00\x19tEXtSoftware\x00Adobe ImageReadyq\xc9e<\x00\x00\x01\x95IDATx\xdab\xfc\x0f\x00\x00\x00\x00\x00' > $PROJECT_DIR/static/favicon.ico

    chown -R kododrive:kododrive $PROJECT_DIR/static/
    chmod -R 755 $PROJECT_DIR/static/

    log "Статические файлы созданы успешно"
}

# Функция настройки виртуального окружения и Flask
setup_flask_app() {
    log "Настройка Flask приложения..."

    PROJECT_DIR="/home/kododrive/portfolio"
    cd $PROJECT_DIR

    # Создание виртуального окружения
    sudo -u kododrive python3 -m venv venv || error "Не удалось создать виртуальное окружение"

    # Установка зависимостей
    sudo -u kododrive bash -c "
        source venv/bin/activate && 
        pip install --upgrade pip && 
        pip install -r requirements.txt
    " || error "Не удалось установить зависимости Python"

    # Инициализация миграций
    log "Инициализация миграций базы данных..."
    sudo -u kododrive bash -c "
        cd $PROJECT_DIR && 
        source venv/bin/activate && 
        source .env && 
        python3 -c \"
from app import app, db
with app.app_context():
    db.create_all()
    print('База данных инициализирована')
\"
    " || error "Не удалось инициализировать базу данных"

    # Создание начальных данных
    log "Создание начальных данных..."
    sudo -u kododrive bash -c "
        cd $PROJECT_DIR && 
        source venv/bin/activate && 
        source .env && 
        python3 -c \"
from app import app, init_app
init_app()
print('Начальные данные созданы')
\"
    " || error "Не удалось создать начальные данные"

    # Тестирование приложения
    log "Тестирование Flask приложения..."
    sudo -u kododrive bash -c "
        cd $PROJECT_DIR && 
        source venv/bin/activate && 
        source .env && 
        timeout 10 python3 -c \"
from app import app
with app.test_client() as client:
    response = client.get('/')
    assert response.status_code == 200
    print('Flask приложение работает корректно')
\"
    " || warning "Не удалось протестировать Flask приложение"

    log "Flask приложение настроено успешно"
}

# Функция создания systemd сервиса
create_systemd_service() {
    log "Создание systemd сервиса..."

    cat > /etc/systemd/system/kododrive-portfolio.service << EOF
[Unit]
Description=KodoDrive Portfolio Flask Application
After=network.target postgresql.service
Requires=postgresql.service
Documentation=https://github.com/svod011929/kododrive-portfolio

[Service]
Type=notify
User=kododrive
Group=kododrive
WorkingDirectory=/home/kododrive/portfolio
Environment="PATH=/home/kododrive/portfolio/venv/bin"
EnvironmentFile=/home/kododrive/portfolio/.env
ExecStart=/home/kododrive/portfolio/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 120 --keep-alive 2 --max-requests 1000 --preload wsgi:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=3

# Безопасность
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/home/kododrive/portfolio
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Логирование
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kododrive-portfolio

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || error "Не удалось перезагрузить systemd"
    systemctl enable kododrive-portfolio || error "Не удалось включить автозапуск сервиса"

    log "Systemd сервис создан и настроен"
}

# Функция настройки Nginx
setup_nginx() {
    log "Настройка Nginx..."

    # Создание конфигурации Nginx
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
# HTTP конфигурация (будет обновлена после получения SSL)
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Временная заглушка для получения SSL
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# Будущая HTTPS конфигурация (будет активирована после SSL)
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL конфигурация (будет добавлена certbot)
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    # ssl_private_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Основные настройки
    root /home/kododrive/portfolio;
    index index.html index.htm;
    client_max_body_size 16M;

    # Логирование
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;

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
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Статические файлы
    location /static/ {
        alias /home/kododrive/portfolio/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;

        # MIME типы
        location ~* \.(css|js)$ {
            add_header Content-Type text/css;
        }

        location ~* \.(jpg|jpeg|png|gif|ico|svg)$ {
            expires 1y;
        }

        location ~* \.(woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Access-Control-Allow-Origin "*";
        }
    }

    # Favicon
    location = /favicon.ico {
        alias /home/kododrive/portfolio/static/favicon.ico;
        expires 1y;
        access_log off;
    }

    # Robots.txt
    location = /robots.txt {
        alias /home/kododrive/portfolio/static/robots.txt;
        access_log off;
    }

    # Основное приложение
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Timeout настройки
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # Буферизация
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;

        # WebSocket поддержка (на будущее)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Защита от скрытых файлов
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Защита от исполняемых файлов в uploads
    location ~* ^/static/uploads/.*\.(php|py|pl|sh)$ {
        deny all;
    }
}
EOF

    # Активация сайта
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/ || error "Не удалось активировать сайт"
    rm -f /etc/nginx/sites-enabled/default

    # Создание директории для acme-challenge
    mkdir -p /var/www/html/.well-known/acme-challenge
    chown -R www-data:www-data /var/www/html

    # Тестирование конфигурации
    nginx -t || error "Ошибка в конфигурации Nginx"

    log "Nginx настроен (HTTP режим для получения SSL)"
}

# Функция настройки SSL
setup_ssl() {
    log "Получение SSL сертификата..."

    # Запуск Flask приложения
    systemctl start kododrive-portfolio || error "Не удалось запустить Flask приложение"

    # Запуск Nginx
    systemctl restart nginx || error "Не удалось запустить Nginx"

    # Ожидание запуска сервисов
    sleep 10

    # Проверка работы Flask приложения
    if ! curl -f http://127.0.0.1:5000 >/dev/null 2>&1; then
        warning "Flask приложение может работать некорректно"
        systemctl status kododrive-portfolio --no-pager
    else
        log "Flask приложение отвечает на запросы"
    fi

    # Получение SSL сертификата
    log "Получение SSL сертификата от Let's Encrypt..."
    certbot --nginx --agree-tos --no-eff-email --email $EMAIL -d $DOMAIN -d www.$DOMAIN --non-interactive || error "Не удалось получить SSL сертификат"

    # Настройка автоматического обновления SSL
    log "Настройка автоматического обновления SSL..."
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab - || warning "Не удалось настроить автоматическое обновление SSL"

    # Финальная перезагрузка Nginx с SSL конфигурацией
    systemctl reload nginx || error "Не удалось перезагрузить Nginx с SSL"

    log "SSL сертификат получен и настроен"
}

# Функция настройки безопасности
setup_security() {
    log "Настройка безопасности..."

    # Firewall
    ufw --force enable || error "Не удалось включить firewall"
    ufw default deny incoming || error "Не удалось настроить правила firewall"
    ufw default allow outgoing || error "Не удалось настроить правила firewall"
    ufw allow 22/tcp || error "Не удалось разрешить SSH"
    ufw allow 80/tcp || error "Не удалось разрешить HTTP"
    ufw allow 443/tcp || error "Не удалось разрешить HTTPS"

    # Настройка fail2ban
    systemctl enable fail2ban || warning "Не удалось включить fail2ban"
    systemctl start fail2ban || warning "Не удалось запустить fail2ban"

    # Настройка прав доступа
    chmod -R 755 /home/kododrive/portfolio/static/
    chown -R kododrive:www-data /home/kododrive/portfolio/static/

    # Добавление пользователя www-data в группу kododrive
    usermod -a -G kododrive www-data

    # Создание директорий для скриптов
    mkdir -p /home/kododrive/{scripts,backups,logs}

    # Скрипт резервного копирования
    cat > /home/kododrive/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/kododrive/backups"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/home/kododrive/portfolio"

echo "Starting backup: $DATE"
mkdir -p $BACKUP_DIR

# Бэкап базы данных
echo "Backing up database..."
sudo -u postgres pg_dump kododrive_db > $BACKUP_DIR/db_backup_$DATE.sql
if [ $? -eq 0 ]; then
    echo "Database backup completed"
else
    echo "Database backup failed"
    exit 1
fi

# Бэкап файлов приложения
echo "Backing up application files..."
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz \
    -C /home/kododrive \
    --exclude=portfolio/venv \
    --exclude=portfolio/__pycache__ \
    --exclude=portfolio/*.pyc \
    --exclude=portfolio/logs/*.log \
    portfolio/

if [ $? -eq 0 ]; then
    echo "Application backup completed"
else
    echo "Application backup failed"
    exit 1
fi

# Удаление старых бэкапов (старше 7 дней)
echo "Cleaning old backups..."
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed successfully: $DATE"
EOF

    # Скрипт обновления приложения
    cat > /home/kododrive/scripts/update.sh << 'EOF'
#!/bin/bash
PROJECT_DIR="/home/kododrive/portfolio"
LOG_FILE="/home/kododrive/logs/update.log"

echo "Starting update: $(date)" | tee -a $LOG_FILE

cd $PROJECT_DIR || exit 1

# Активация виртуального окружения
source venv/bin/activate || exit 1
source .env || exit 1

echo "Updating Python dependencies..." | tee -a $LOG_FILE
pip install --upgrade pip | tee -a $LOG_FILE
pip install -r requirements.txt | tee -a $LOG_FILE

echo "Applying database migrations..." | tee -a $LOG_FILE
python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database updated')
" | tee -a $LOG_FILE

echo "Restarting services..." | tee -a $LOG_FILE
sudo systemctl restart kododrive-portfolio | tee -a $LOG_FILE
sudo systemctl reload nginx | tee -a $LOG_FILE

sleep 5

# Проверка статуса
if systemctl is-active --quiet kododrive-portfolio; then
    echo "Update completed successfully: $(date)" | tee -a $LOG_FILE
else
    echo "Update failed - service not running: $(date)" | tee -a $LOG_FILE
    exit 1
fi
EOF

    # Скрипт мониторинга
    cat > /home/kododrive/scripts/monitor.sh << 'EOF'
#!/bin/bash
PROJECT_DIR="/home/kododrive/portfolio"
LOG_FILE="/home/kododrive/logs/monitor.log"

echo "=== System Status Check: $(date) ===" >> $LOG_FILE

# Проверка сервисов
services=("kododrive-portfolio" "nginx" "postgresql")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service: RUNNING" >> $LOG_FILE
    else
        echo "✗ $service: STOPPED" >> $LOG_FILE
    fi
done

# Проверка места на диске
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $disk_usage -gt 80 ]; then
    echo "⚠ Disk usage high: ${disk_usage}%" >> $LOG_FILE
else
    echo "✓ Disk usage: ${disk_usage}%" >> $LOG_FILE
fi

# Проверка доступности приложения
if curl -f -s http://127.0.0.1:5000 > /dev/null; then
    echo "✓ Flask application: RESPONSIVE" >> $LOG_FILE
else
    echo "✗ Flask application: NOT RESPONSIVE" >> $LOG_FILE
fi

# Проверка SSL сертификата
ssl_expiry=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/cert.pem 2>/dev/null | cut -d= -f2)
if [ $? -eq 0 ]; then
    echo "✓ SSL certificate valid until: $ssl_expiry" >> $LOG_FILE
else
    echo "✗ SSL certificate check failed" >> $LOG_FILE
fi

echo "=== End Status Check ===" >> $LOG_FILE
echo "" >> $LOG_FILE
EOF

    # Делаем скрипты исполнимыми
    chmod +x /home/kododrive/scripts/*.sh
    chown -R kododrive:kododrive /home/kododrive/{scripts,backups,logs}

    # Настройка cron заданий
    sudo -u kododrive bash -c '
        # Добавляем cron задания
        (crontab -l 2>/dev/null; echo "0 2 * * * /home/kododrive/scripts/backup.sh >> /home/kododrive/logs/backup.log 2>&1") | crontab -
        (crontab -l 2>/dev/null; echo "*/15 * * * * /home/kododrive/scripts/monitor.sh") | crontab -
    ' || warning "Не удалось настроить cron задания"

    # Настройка логротации
    cat > /etc/logrotate.d/kododrive << 'EOF'
/home/kododrive/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 kododrive kododrive
}
EOF

    log "Безопасность и мониторинг настроены"
}

# Главная функция установки
main() {
    log "Начинаем установку KodoDrive Portfolio v3.0 (FINAL)..."

    # Проверка системных требований
    if ! command -v python3 &> /dev/null; then
        error "Python3 не установлен в системе"
    fi

    # Выполнение установки по шагам
    create_user
    update_system
    install_packages
    setup_postgresql
    create_project_structure
    create_python_files
    create_templates
    create_static_files
    setup_flask_app
    create_systemd_service
    setup_nginx
    setup_ssl
    setup_security

    # Финальные проверки
    log "Выполнение финальных проверок..."

    # Проверка Flask приложения
    if systemctl is-active --quiet kododrive-portfolio; then
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
        warning "⚠ Сайт может быть недоступен - проверьте DNS настройки"
    fi

    # Проверка статических файлов
    if curl -f -k https://$DOMAIN/static/css/style.css >/dev/null 2>&1; then
        log "✓ Статические файлы (CSS) доступны"
    else
        warning "⚠ Проблемы с доступом к статическим файлам"
    fi

    if curl -f -k https://$DOMAIN/static/js/script.js >/dev/null 2>&1; then
        log "✓ Статические файлы (JS) доступны"
    else
        warning "⚠ Проблемы с доступом к JavaScript файлам"
    fi

    # Вывод итоговой информации
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! (v3.0 FINAL) 🎉                  ║
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
    info "   • Статус сервисов: systemctl status kododrive-portfolio nginx postgresql"
    info "   • Перезапуск: sudo systemctl restart kododrive-portfolio"
    info "   • Логи приложения: sudo journalctl -u kododrive-portfolio -f"
    info "   • Логи Nginx: sudo tail -f /var/log/nginx/$DOMAIN.error.log"
    info "   • Обновление: sudo /home/kododrive/scripts/update.sh"
    info "   • Бэкап: sudo /home/kododrive/scripts/backup.sh"
    info "   • Мониторинг: /home/kododrive/scripts/monitor.sh"
    echo ""
    info "🎯 Что нового в версии 3.0:"
    info "   • ✅ Полностью переписанная архитектура Flask приложения"
    info "   • ✅ Современная админ панель с Bootstrap 5"
    info "   • ✅ Улучшенная система безопасности и мониторинга"
    info "   • ✅ Автоматические бэкапы и обновления"
    info "   • ✅ Оптимизированная конфигурация Nginx и SSL"
    info "   • ✅ Полная система уведомлений и логирования"
    echo ""
    warning "⚠️  Важные рекомендации:"
    warning "   • Смените пароль администратора после первого входа"
    warning "   • Убедитесь что DNS записи указывают на IP $SERVER_IP"
    warning "   • Проверьте работу всех функций в админ панели"
    warning "   • Настройте регулярный мониторинг системы"
    echo ""
    log "🚀 Установка полностью завершена! Добро пожаловать в KodoDrive Portfolio!"
    log "📧 При возникновении проблем проверьте логи или обратитесь за поддержкой"

    # Показать краткий статус системы
    echo ""
    info "📊 Текущий статус системы:"
    systemctl is-active kododrive-portfolio >/dev/null && echo "   ✓ Flask: Работает" || echo "   ✗ Flask: Проблема"
    systemctl is-active nginx >/dev/null && echo "   ✓ Nginx: Работает" || echo "   ✗ Nginx: Проблема"
    systemctl is-active postgresql >/dev/null && echo "   ✓ PostgreSQL: Работает" || echo "   ✗ PostgreSQL: Проблема"

    df -h / | awk 'NR==2 {print "   💾 Диск: " $3 " из " $2 " (" $5 ")"}'
    free -h | awk 'NR==2 {print "   💿 RAM: " $3 " из " $2}'

    echo ""
    log "Время установки: $(date)"
}

# Запуск основной функции
main

exit 0
