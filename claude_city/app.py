import os

import pymysql
from flask import Flask, render_template

from factory import get_provider
from providers.base import NotConfiguredError

app = Flask(__name__)
MODE = os.environ.get("MODE", "env")


@app.route("/")
def index():
    try:
        provider = get_provider(MODE)
        host, user, password, source_label = provider.get_db_credentials()
    except ValueError as exc:
        return render_template("error.html", message=str(exc)), 400
    except NotConfiguredError as exc:
        return render_template("error.html", message=str(exc)), 503
    except KeyError as exc:
        return render_template("error.html", message=f"Missing required environment variable: {exc}"), 503

    try:
        conn = pymysql.connect(
            host=host,
            user=user,
            password=password,
            database="world",
            connect_timeout=5,
        )
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT Name, CountryCode, Population FROM city ORDER BY RAND() LIMIT 1"
                )
                row = cur.fetchone()
        city = {"name": row[0], "country": row[1], "population": f"{row[2]:,}"}
    except Exception as exc:
        return render_template("error.html", message=f"Database error: {exc}"), 503

    return render_template(
        "index.html",
        city=city,
        db_host=host,
        db_user=user,
        db_pass=password,
        source_label=source_label,
        badge_class=provider.badge_class,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
