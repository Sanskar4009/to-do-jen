import logging
import sys
from flask import Flask, render_template

from app.config import Config
from app.utils import format_iso_timestamp


def setup_logging():
    """Configure structured logging for the application."""
    log_format = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    logging.basicConfig(
        level=logging.INFO,
        format=log_format,
        handlers=[logging.StreamHandler(sys.stdout)],
    )


def create_app(config_class=Config):
    """Application factory for the CloudTodo Flask application."""
    setup_logging()
    logger = logging.getLogger(__name__)

    app = Flask(__name__)
    app.config.from_object(config_class)

    # Register custom template filters
    @app.template_filter("format_iso")
    def format_iso_filter(value):
        return format_iso_timestamp(value)

    # Register blueprints
    from app.routes import bp as main_bp
    app.register_blueprint(main_bp)

    # Register custom error handlers
    @app.errorhandler(404)
    def page_not_found(e):
        return render_template("404.html"), 404

    @app.errorhandler(500)
    def internal_server_error(e):
        logger.error("Internal server error: %s", str(e))
        return render_template("500.html"), 500

    logger.info(
        "CloudTodo Flask Application initialized. Region: %s | DynamoDB Table: %s | SNS Enabled: %s",
        app.config.get("AWS_REGION"),
        app.config.get("DYNAMODB_TABLE"),
        bool(app.config.get("SNS_TOPIC_ARN")),
    )

    return app
