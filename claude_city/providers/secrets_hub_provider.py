from .base import NotConfiguredError, SecretsProvider


class SecretsHubProvider(SecretsProvider):
    badge_class = "bg-success"

    def get_db_credentials(self) -> tuple[str, str, str, str]:
        raise NotConfiguredError("Secrets Hub not yet configured")
