from .base import NotConfiguredError, SecretsProvider


class CcpProvider(SecretsProvider):
    badge_class = "bg-warning text-dark"

    def get_db_credentials(self) -> tuple[str, str, str, str]:
        raise NotConfiguredError("CCP not yet configured")
