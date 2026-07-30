"""Tests for the conditional eth1 provisioning in playbook/playbook.yml."""

import json

import pytest


def _shared_metadata(host):
    result = host.run("cat /etc/ansible-test-metadata.json")
    assert result.rc == 0
    return json.loads(result.stdout)


def test_ssh_connection(host):
    """The raw connection check in the playbook must be able to run."""
    assert host.run("/bin/true").rc == 0


def test_hostname_is_shared_from_ansible(host):
    metadata = _shared_metadata(host)
    assert host.run("hostname").stdout.strip() == metadata["hostname"]


@pytest.fixture
def eth1(host):
    """Skip eth1 assertions when the optional host-only NIC is absent."""
    if host.run("test -d /sys/class/net/eth1").rc != 0:
        pytest.skip("eth1 is not present on this host")
    return host


def test_eth1_has_configured_ipv4_address(eth1):
    metadata = _shared_metadata(eth1)
    eth1_device = metadata["eth1"]["device"]
    expected_address = metadata["eth1"]["ip_address"]
    expected_prefix_length = metadata["eth1"]["prefix_length"]

    address = eth1.run(
        f"PATH=/sbin:/usr/sbin:/bin:/usr/bin ip -4 addr show dev {eth1_device}"
    )

    assert address.rc == 0
    assert f"inet {expected_address}/{expected_prefix_length}" in address.stdout


def test_eth1_is_administratively_up(eth1):
    metadata = _shared_metadata(eth1)
    flags = eth1.run(f"cat /sys/class/net/{metadata['eth1']['device']}/flags")

    assert flags.rc == 0
    assert int(flags.stdout.strip(), 16) & 0x1
