import pytest

from factory import get_provider
from providers.ccp_provider import CcpProvider
from providers.conjur_provider import ConjurProvider
from providers.env_provider import EnvProvider
from providers.secrets_hub_provider import SecretsHubProvider


@pytest.mark.parametrize(
    "mode, expected_class",
    [
        ("env", EnvProvider),
        ("conjur", ConjurProvider),
        ("ccp", CcpProvider),
        ("secrets-hub", SecretsHubProvider),
    ],
)
def test_get_provider_returns_correct_class(mode, expected_class):
    assert isinstance(get_provider(mode), expected_class)


def test_get_provider_unknown_mode_raises_value_error():
    with pytest.raises(ValueError, match="Unknown MODE"):
        get_provider("unknown-mode")
