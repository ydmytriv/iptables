#!/bin/bash
export IPT="iptables"

export IP_prov=172.25.233.1
export PROXY_prov=172.25.0.2
export PROXY_port=3128

#зовн інтерфейс
export WAN=ens33
export WAN_IP=172.19.18.1

#локальна мережа
export LAN=ens37
export LAN_IP_RANGE=192.168.203.0/24

#Очистка правил
$IPT -F
$IPT -F -t nat
$IPT -F -t mangle
$IPT -X
$IPT -t nat -X
$IPT -t mangle -X

#заборона всього що не дозволено
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

#localhost i локалка
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -i $LAN -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A OUTPUT -o $LAN -j ACCEPT

# дозв ftp
iptables -A INPUT -p tcp -m tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 20 -j ACCEPT

#дозв пінги
$IPT -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
#$IPT -A INPUT -s $IP_prov -p icmp --icmp-type echo-request -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

#дозв traceroute
$IPT -A OUTPUT -p udp --dport 33434:33534 -j ACCEPT
$IPT -A INPUT -s $IP_prov -p udp --dport 33434:33534 -j ACCEPT

#дозв доступ до проксі провайдера
$IPT -A OUTPUT -p tcp -d $PROXY_prov --dport $PROXY_port -j ACCEPT 

#доступ до пошти
$IPT -A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
$IPT -A INPUT -i $LAN -p tcp --dport 110 -j ACCEPT
$IPT -A INPUT -p tcp -i $WAN --dport 25 -j ACCEPT
$IPT -A OUTPUT -p tcp --sport 110 -j ACCEPT
$IPT -A OUTPUT -p tcp --sport 25 -j ACCEPT
$IPT -A OUTPUT -p tcp --sport 143 -j ACCEPT

#заборона вхідного telnet
$IPT -A INPUT -p tcp --dport 23 -j DROP

#дозв вихідний telnet
$IPT -A OUTPUT -p tcp --sport 23 -j ACCEPT

#дозв вихідні прідкл. сервера
#$IPT -A OUTPUT -o $WAN -j ACCEPT
#$IPT -A INPUT -i $LAN -j ACCEPT

#дозв www
$IPT -A OUTPUT -p tcp --dport 80 -j ACCEPT
#дозв https
$IPT -A OUTPUT -p tcp --dport 443 -j ACCEPT
#дозв ftp
$IPT -A OUTPUT -o $WAN -p tcp --sport 20 -j ACCEPT
$IPT -A OUTPUT -p tcp --dport 21 -j ACCEPT
#дозв dns
$IPT -A OUTPUT -p tcp --dport 53 -j ACCEPT
$IPT -A OUTPUT -p udp --dport 53 -j ACCEPT

#дозв встановлені підкл
$IPT -A INPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A FORWARD -p all -m state --state ESTABLISHED,RELATED -j ACCEPT

#відк неопізнані пакети
#$IPT -A INPUT -m state --state INVALID -j DROP
#$IPT -A FORWARD -m state --state INVALID -j DROP

#відк нулеві пакети
#$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

#закр від syn-flood атак
#$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
#$IPT -A OUTPUT -p tcp ! --syn -m state --state NEW -j DROP

#блок доступ з вказаних адрес
$IPT -A INPUT -s 160.25.0.0/16 -j DROP

#блок спамера
$IPT -A INPUT -p tcp -i $WAN -s 15.1.23.22 --destination-port 25 -j DROP

#блок вхідних фрагментованих пакетів
$IPT -A INPUT -f -j DROP

#Дозволяємо доступ з лок назовні
#$IPT -A FORWARD -i $LAN -o $WAN -j ACCEPT

#дозволи для машин в мережі
#WWW
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --dport 80 -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --dport 443 -j ACCEPT
#ftp
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --sport 20 -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --dport 21 -j ACCEPT
#ssh
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --dport 22 -j ACCEPT
#dns
$IPT -A FORWARD -i $LAN -o $WAN -p tcp --dport 53 -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p udp --dport 53 -j ACCEPT
#ping
$IPT -A FORWARD -i $LAN -o $WAN -p icmp --icmp-type echo-reply -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p icmp --icmp-type destination-unreachable -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p icmp --icmp-type time-exceeded -j ACCEPT
$IPT -A FORWARD -i $LAN -o $WAN -p icmp --icmp-type echo-request -j ACCEPT
#ext proxy
$IPT -A FORWARD -i $LAN -o $WAN -d $PROXY_prov -p tcp --dport 3128 -j ACCEPT
$IPT -t nat -A PREROUTING -p tcp --dport $PROXY_port -i ${WAN} -j DNAT --to 192.168.203.131

#spoofing
$IPT -I INPUT -m addrtype --src-type LOCAL ! -i lo -j DROP


#блок доступ з зовн в середину
#$IPT -A FORWARD -i $LAN -o $LAN1 -j REJECT

#вкл NAT, маскування трафіку лок. мережі
$IPT -t nat -A POSTROUTING -o $WAN -s $LAN_IP_RANGE -j MASQUERADE

#відкр доступ до SSH
$IPT -A INPUT -i $WAN -p tcp --dport 22 -j ACCEPT


#прокидуємо порт
$IPT -t nat -A PREROUTING -p tcp --dport 80 -i ${WAN} -j DNAT --to 192.168.203.131
$IPT -t nat -A PREROUTING -p tcp --dport 443 -i ${WAN} -j DNAT --to 192.168.203.131
$IPT -A FORWARD -i $WAN -d 192.168.203.131 -p tcp -m tcp --dport 80 -j ACCEPT
$IPT -A FORWARD -i $WAN -d 192.168.203.131 -p tcp -m tcp --dport 443 -j ACCEPT


