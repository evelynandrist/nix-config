#!/usr/bin/env python3

# Based on Birk Blechschmidt's awesome fakeroute https://github.com/blechschmidt/fakeroute

import argparse
import atexit
import ipaddress
import logging
import os
import select
import socket

from pyroute2.nftables.main import NFTables
from scapy.layers.inet6 import IPv6, ICMPv6TimeExceeded

ETH_P_IP6 = socket.htons(0x86dd)

COUNT = 45
PREFIX = "2a03:4000:5a:cd:dead:beef:cafe:"

def nftables_ttl_lte_expression(ttl):
    """
    Generate NFTables rules that drop IPv6 packets with a TTL/hop limit <= ttl
    :param ttl: The TTL.
    :return: Rule that can be supplied to pyroute2.
    """
    return [
        # Load TTL
        {'attrs': [('NFTA_EXPR_NAME', 'payload'),
                   ('NFTA_EXPR_DATA',
                    {'attrs': [('NFTA_PAYLOAD_DREG', 1),
                               ('NFTA_PAYLOAD_BASE', 1),
                               ('NFTA_PAYLOAD_OFFSET', 7),
                               ('NFTA_PAYLOAD_LEN', 1)]})]},
        # Compare
        {'attrs': [('NFTA_EXPR_NAME', 'cmp'),
                   ('NFTA_EXPR_DATA',
                    {'attrs': [('NFTA_CMP_SREG', 1),
                               ('NFTA_CMP_OP', 3),
                               ('NFTA_CMP_DATA', {'attrs': [('NFTA_DATA_VALUE', bytes([ttl]))]})]})]},
        # Drop
        {'attrs': [('NFTA_EXPR_NAME', 'immediate'),
                   ('NFTA_EXPR_DATA',
                    {'attrs': [('NFTA_IMMEDIATE_DREG', 0),
                               ('NFTA_IMMEDIATE_DATA',
                                {'attrs': [('NFTA_DATA_VERDICT',
                                            {'attrs': [('NFTA_VERDICT_CODE', 0)]})]})]})]}
    ]


def get_packet_info(payload):
    return ipaddress.ip_address(payload[8:8 + 16]), ipaddress.ip_address(payload[24:24 + 16]), payload[7]


class TracerouteFakeTarget:
    """
    This is to be run on the server for which the traceroute should be faked. This class uses raw sockets to capture
    incoming IP addresses and sets up firewall rules that drop packets with a low TTL, so that the operating system does
    interfere with our fake replies. When packets with a low TTL are captured, fake replies are generated.
    """

    def __init__(self, addresses):
        self.addrs = [ipaddress.ip_address(addr) for addr in addresses]
        self.socket = socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_RAW)

        atexit.register(self.delete_firewall_rules)
        self.setup_firewall()

    def setup_firewall(self):
        # noinspection PyUnresolvedReferences
        with NFTables(nfgen_family=socket.AF_INET6) as nft:
            nft.table('add', name='fakeroute')
            nft.chain('add', table='fakeroute', name='fakeroute', type='filter', hook='input')
            exp = nftables_ttl_lte_expression(len(self.addrs))
            nft.rule('add', table='fakeroute', chain='fakeroute', expressions=(exp,))

    def delete_firewall_rules(self, *_, **__):
        # noinspection PyUnresolvedReferences
        with NFTables(nfgen_family=socket.AF_INET6) as nft:
            nft.table('del', name='fakeroute')

    def spoof(self, payload):
        src, dst, ttl = get_packet_info(payload)
        spoof_addr = str(self.addrs[ttl - 1])
        logging.debug("Spoof IPv6 packet from %s to %s" % (spoof_addr, src))
        packet = IPv6(src=spoof_addr, dst=src) / ICMPv6TimeExceeded() / payload
        packet = bytes(packet)
        _, dst, _ = get_packet_info(packet)
        self.socket.sendto(packet, (str(dst), 0))

    def run(self):
        sockets = [socket.socket(socket.AF_PACKET, socket.SOCK_DGRAM, ETH_P_IP6)]
        while True:
            read, _, _ = select.select(sockets, [], [])
            for r in read:
                payload, _ = r.recvfrom(0xffff)
                src, dst, ttl = get_packet_info(payload)
                if 1 <= ttl <= len(self.addrs):
                    self.spoof(payload)


def main():
    logging.basicConfig(level=os.environ.get('LOGLEVEL', 'INFO'))

    parser = argparse.ArgumentParser(description='Fake traceroute generator')
    parser.add_argument('--count', help='Number of hops to generate')
    parser.add_argument('--prefix', help='First 112 bits of the IPv6 addresses to be generated, e.g. 2a03:4000:5a:cd:dead:beef:cafe:')
    args = parser.parse_args()
    count = args.count if args.count is not None else COUNT
    prefix = args.prefix if args.prefix is not None else PREFIX
    addresses = [ prefix + x.lstrip('0').lstrip('x') for x in map(hex, range(count)) ]

    faker = TracerouteFakeTarget(addresses)
    faker.run()

if __name__ == '__main__':
    main()
