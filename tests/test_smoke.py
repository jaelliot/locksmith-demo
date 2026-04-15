"""
Smoke tests for locksmith-demo.

These tests are headless and require no running witnesses, no display,
and no network access. They verify that:
  1. The locksmith package imports correctly after installation.
  2. The KERI layer (keripy) can incept an in-memory AID.
  3. The LocksmithConfig layer initialises without raising.

Run with:
    pytest tests/ -v
"""
import pytest


class TestImports:
    """Verify the locksmith package tree loads after `pip install -e .`."""

    def test_core_configing(self):
        from locksmith.core.configing import LocksmithConfig  # noqa: F401

    def test_core_habbing(self):
        from locksmith.core.habbing import open_hby  # noqa: F401

    def test_core_vaulting(self):
        from locksmith.core.vaulting import Vault  # noqa: F401

    def test_plugins_base(self):
        from locksmith.plugins.base import LocksmithPlugin  # noqa: F401


class TestKeriLayer:
    """Verify the KERI primitives work at the keripy level (temp, in-memory)."""

    def test_aid_inception(self):
        """
        Incept a single-key non-transferable AID in a temp in-memory Habery.
        Proves the full keripy stack (signing, LMDB substitute, event log) works.
        """
        from keri.app import habbing

        with habbing.openHby(name="smoke", salt="0ACDEyMzQ1Njc4OWxtbm9aBc", temp=True) as hby:
            hab = hby.makeHab(name="test-aid", transferable=False)
            prefix = hab.pre
            assert prefix, "AID prefix must not be empty"
            # CESR non-transferable signing key derivation codes start with 'B'
            # transferable codes start with 'E'
            assert prefix[0] in ("B", "E"), f"Unexpected prefix derivation code: {prefix[0]}"

    def test_transferable_aid_has_next_key_digest(self):
        """
        Incept a transferable AID and confirm a next-key digest is committed.
        This exercises the pre-rotation path.
        """
        from keri.app import habbing

        with habbing.openHby(name="smoke2", salt="0ACDEyMzQ1Njc4OWxtbm9dEf", temp=True) as hby:
            hab = hby.makeHab(name="transferable-aid", transferable=True)
            state = hab.state()
            nxt = state.get("n", [])
            assert nxt, "Transferable AID must commit to at least one next-key digest"


class TestConfig:
    """Verify the LocksmithConfig layer initialises without a display or database."""

    def test_config_loads(self):
        from locksmith.core.configing import LocksmithConfig

        cfg = LocksmithConfig.get_instance()
        assert cfg is not None
