from .base import NotConfiguredError, SecretsProvider


class ConjurProvider(SecretsProvider):
    badge_class = "bg-primary"

    def get_db_credentials(self) -> tuple[str, str, str, str]:
        raise NotConfiguredError("Conjur not yet configured")
