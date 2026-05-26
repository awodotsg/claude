from abc import ABC, abstractmethod


class NotConfiguredError(Exception):
    pass


class SecretsProvider(ABC):
    badge_class: str = "bg-secondary"

    @abstractmethod
    def get_db_credentials(self) -> tuple[str, str, str, str]:
        """Return (host, user, password, source_label)."""
