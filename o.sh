apt-get install openssl pkg-config libssl-dev -y
apt install -y cargo curl build-essential
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
cargo install ore-hq-client
mkdir -p ~/.config/solana && touch ~/.config/solana/id.json && nano ~/.config/solana/id.json
