import logging
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Set, Tuple

import netaddr
from netaddr import EUI, IPNetwork

from core.gui.graph.node import CanvasNode
from core.gui.nodeutils import NodeUtils
from core.gui.wrappers import Interface, Link, Node

if TYPE_CHECKING:
    from core.gui.app import Application


def get_index(iface: Interface) -> Optional[int]:
    if not iface.ip4:
        return None
    net = netaddr.IPNetwork(f"{iface.ip4}/{iface.ip4_mask}")
    ip_value = net.value
    cidr_value = net.cidr.value
    return ip_value - cidr_value


class Subnets:
    def __init__(self, ip4: IPNetwork, ip6: IPNetwork) -> None:
        self.ip4 = ip4
        self.ip6 = ip6
        self.used_indexes = set()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, Subnets):
            return False
        return self.key() == other.key()

    def __hash__(self) -> int:
        return hash(self.key())

    def key(self) -> Tuple[IPNetwork, IPNetwork]:
        return self.ip4, self.ip6

    def next(self) -> "Subnets":
        return Subnets(self.ip4.next(), self.ip6.next())


class InterfaceManager:
    def __init__(self, app: "Application") -> None:
        self.app: "Application" = app
        ip4 = self.app.guiconfig.ips.ip4
        ip6 = self.app.guiconfig.ips.ip6
        self.ip4_mask: int = 24
        self.ip6_mask: int = 64
        self.ip4_subnets: IPNetwork = IPNetwork(f"{ip4}/{self.ip4_mask}")
        self.ip6_subnets: IPNetwork = IPNetwork(f"{ip6}/{self.ip6_mask}")
        mac = self.app.guiconfig.mac
        self.mac: EUI = EUI(mac, dialect=netaddr.mac_unix_expanded)
        self.current_mac: Optional[EUI] = None
        self.current_subnets: Optional[Subnets] = None
        self.used_subnets: Dict[Tuple[IPNetwork, IPNetwork], Subnets] = {}

    def update_ips(self, ip4: str, ip6: str) -> None:
        self.reset()
        self.ip4_subnets = IPNetwork(f"{ip4}/{self.ip4_mask}")
        self.ip6_subnets = IPNetwork(f"{ip6}/{self.ip6_mask}")

    def reset_mac(self) -> None:
        self.current_mac = self.mac

    def next_mac(self) -> str:
        mac = str(self.current_mac)
        value = self.current_mac.value + 1
        self.current_mac = EUI(value, dialect=netaddr.mac_unix_expanded)
        return mac

    def next_subnets(self) -> Subnets:
        subnets = self.current_subnets
        if subnets is None:
            subnets = Subnets(self.ip4_subnets, self.ip6_subnets)
        while subnets.key() in self.used_subnets:
            subnets = subnets.next()
        self.used_subnets[subnets.key()] = subnets
        return subnets

    def reset(self) -> None:
        self.current_subnets = None
        self.used_subnets.clear()

    def removed(self, links: List[Link]) -> None:
        # get remaining subnets
        remaining_subnets = set()
        for edge in self.app.core.links.values():
            link = edge.link
            if link.iface1:
                subnets = self.get_subnets(link.iface1)
                remaining_subnets.add(subnets)
            if link.iface2:
                subnets = self.get_subnets(link.iface2)
                remaining_subnets.add(subnets)

        # remove all subnets from used subnets when no longer present
        # or remove used indexes from subnet
        ifaces = []
        for link in links:
            if link.iface1:
                ifaces.append(link.iface1)
            if link.iface2:
                ifaces.append(link.iface2)
        for iface in ifaces:
            subnets = self.get_subnets(iface)
            if subnets not in remaining_subnets:
                self.used_subnets.pop(subnets.key(), None)
            else:
                index = get_index(iface)
                if index is not None:
                    subnets.used_indexes.discard(index)
        self.current_subnets = None

    def joined(self, links: List[Link]) -> None:
        ifaces = []
        for link in links:
            if link.iface1:
                ifaces.append(link.iface1)
            if link.iface2:
                ifaces.append(link.iface2)

        # add to used subnets and mark used indexes
        for iface in ifaces:
            subnets = self.get_subnets(iface)
            index = get_index(iface)
            if index is None:
                continue
            subnets.used_indexes.add(index)
            if subnets.key() not in self.used_subnets:
                self.used_subnets[subnets.key()] = subnets

    def next_index(self, node: Node) -> int:
        if NodeUtils.is_router_node(node):
            index = 1
        else:
            index = 20
        while True:
            if index not in self.current_subnets.used_indexes:
                self.current_subnets.used_indexes.add(index)
                break
            index += 1
        return index

    def get_ips(self, node: Node) -> [str, str]:
        index = self.next_index(node)
        ip4 = self.current_subnets.ip4[index]
        ip6 = self.current_subnets.ip6[index]
        return str(ip4), str(ip6)

    def get_subnets(self, iface: Interface) -> Subnets:
        ip4_subnet = self.ip4_subnets
        if iface.ip4:
            ip4_subnet = IPNetwork(f"{iface.ip4}/{iface.ip4_mask}").cidr
        ip6_subnet = self.ip6_subnets
        if iface.ip6:
            ip6_subnet = IPNetwork(f"{iface.ip6}/{iface.ip6_mask}").cidr
        subnets = Subnets(ip4_subnet, ip6_subnet)
        return self.used_subnets.get(subnets.key(), subnets)

    def determine_subnets(
        self, canvas_src_node: CanvasNode, canvas_dst_node: CanvasNode
    ) -> None:
        src_node = canvas_src_node.core_node
        dst_node = canvas_dst_node.core_node
        is_src_container = NodeUtils.is_container_node(src_node.type)
        is_dst_container = NodeUtils.is_container_node(dst_node.type)
        if is_src_container and is_dst_container:
            self.current_subnets = self.next_subnets()
        elif is_src_container and not is_dst_container:
            subnets = self.find_subnets(canvas_dst_node, visited={src_node.id})
            if subnets:
                self.current_subnets = subnets
            else:
                self.current_subnets = self.next_subnets()
        elif not is_src_container and is_dst_container:
            subnets = self.find_subnets(canvas_src_node, visited={dst_node.id})
            if subnets:
                self.current_subnets = subnets
            else:
                self.current_subnets = self.next_subnets()
        else:
            logging.info("ignoring subnet change for link between network nodes")

    def find_subnets(
        self, canvas_node: CanvasNode, visited: Set[int] = None
    ) -> Optional[IPNetwork]:
        logging.info("finding subnet for node: %s", canvas_node.core_node.name)
        canvas = self.app.canvas
        subnets = None
        if not visited:
            visited = set()
        visited.add(canvas_node.core_node.id)
        for edge in canvas_node.edges:
            src_node = canvas.nodes[edge.src]
            dst_node = canvas.nodes[edge.dst]
            iface = edge.src_iface
            check_node = src_node
            if src_node == canvas_node:
                iface = edge.dst_iface
                check_node = dst_node
            if check_node.core_node.id in visited:
                continue
            visited.add(check_node.core_node.id)
            if iface:
                subnets = self.get_subnets(iface)
            else:
                subnets = self.find_subnets(check_node, visited)
            if subnets:
                logging.info("found subnets: %s", subnets)
                break
        return subnets
