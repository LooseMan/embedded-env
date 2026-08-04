## 🌐 ネットワークの全体像（libvirt構成）

 [RHEL9 ホストOS (IP: 192.168.100.1)]
        │ (NetworkManagerが管理)
 ┌──────┴──────────────────────────┐
 │ 仮想ブリッジ (virbr1)           │ ← libvirtが自動生成する仮想デバイス
 └──────┬──────────────────┬───────┘
        │                  │
 ┌──────┴──────┐    ┌──────┴──────┐
 │ vnet0       │    │ vnet1       │ ← 仮想化用TAPアダプター（自動生成）
 └──────┬──────┘    └──────┬──────┘
        │ (論理配線)        │
 ┌──────┴──────┐    ┌──────┴──────┐
 │ 仮想NIC     │    │ 仮想NIC     │ ← ゲストOSに見せるNIC (virtio)
 ├─────────────┤ ├─────────────┤
 │ ゲストVM 1  │    │ ゲストVM 2  │
 │(192.168.100.11)  │(192.168.100.12)
 └─────────────┘    └─────────────┘
  ※ VM間、VM⇔ホスト間の双方向通信がすべて可能（DHCPも利用可能）

------------------------------
## 🛠️ RHEL9での具体的な設定手順
libvirt のXML定義ファイルを使い、ホスト側に仮想ネットワークデバイス（ブリッジ）を作成してVMを紐付けます。
## ステップ1：仮想ネットワーク定義ファイルの作成
ホストOS側で、新しいネットワークを定義するXMLファイル（例：private_net.xml）を作成します。今回はDHCPサーバー機能も内蔵させ、IPアドレスが自動で割り当てられるようにします。

<network>
  <name>private-net</name>
  <bridge name='virbr1' stp='on' delay='0'/>
  <!-- ip、mac、dns等は必要に応じて。forwardタグを入れないことで「ホスト+VM間」に限定（Isolated） -->
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dns>
      <enable value='yes'/>
    </dns>
    <dhcp>
      <range start='192.168.100.10' end='192.168.100.50'/>
    </dhcp>
  </ip>
</network>


* ※もしこのネットワークからインターネット（外の世界）にも繋げたい場合は、<network>タグの直下に <forward mode='nat'/> を1行追加するだけで、RHEL9のnftablesと連動したNATルーターとして機能します。

## ステップ2：libvirtへネットワークを登録・起動
ホストOSのターミナルで、作成したXMLを virsh コマンドで読み込ませます。

# 1. ネットワークを登録
sudo virsh net-define private_net.xml
# 2. ネットワークを起動
sudo virsh net-start private-net
# 3. ホスト起動時に自動で有効化するよう設定
sudo virsh net-autostart private-net

この時点で、ホストOS側には自動的に virbr1 という仮想ネットワークデバイス（ブリッジ）が作成され、IP 192.168.100.1 が付与されます。
## ステップ3：仮想マシン（NIC）の紐付け
仮想マシンを作成または編集する際、ネットワークの接続先として先ほど作った private-net を指定し、NICのモデルを virtio（RHEL9の最適値）に設定します。
【新規作成時のコマンド例（virt-install）】

virt-install \
  --name vm1 \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20,format=qcow2 \
  --os-variant rhel9.0 \
  --network network=private-net,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --location /path/to/rhel9.iso


* --network network=private-net,model=virtio: これにより、ゲストOS内に高性能なVirtIO仕様の仮想NICが搭載され、ホスト側の仮想ネットワークデバイス（private-net）へ自動的にLANケーブルが差し込まれた状態になります。

ゲストOS（Linux）が起動すると、内蔵のDHCPサーバーから 192.168.100.x のIPアドレスが自動で取得され、追加の手動設定なしで VM1 ⇔ VM2 ⇔ ホストOS の通信がすべて開通します。
