from providers.base import SecretsProvider
from providers.ccp_provider import CcpProvider
from providers.conjur_provider import ConjurProvider
from providers.env_provider import EnvProvider
from providers.secrets_hub_provider import SecretsHubProvider

_PROVIDERS: dict[str, type[SecretsProvider]] = {
    "env": EnvProvider,
    "conjur": ConjurProvider,
    "ccp": CcpProvider,
    "secrets-hub": SecretsHubProvider,
}


def get_provider(mode: str) -> SecretsProvider:
    if mode not in _PROVIDERS:
        raise ValueError(f"Unknown MODE: {mode!r}. Valid values: {list(_PROVIDERS)}")
    return _PROVIDERS[mode]()
