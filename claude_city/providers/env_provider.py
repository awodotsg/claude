import os

from .base import SecretsProvider


class EnvProvider(SecretsProvider):
    badge_class = "bg-secondary"

    def get_db_credentials(self) -> tuple[str, str, str, str]:
        host = os.environ["DBADDR"]
        user = os.environ["DBUSER"]
        password = os.environ["DBPASS"]
        return host, user, password, "Environment Variables"
