#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Eclipse.sh"

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne "0" ]; then
  echo "请以 root 用户或使用 sudo 运行此脚本"
  exit 1
fi

deploy_environment() {
    install_solana() {
        if ! command -v solana &> /dev/null; then
            echo "未找到 Solana。正在安装 Solana..."
            sh -c "$(curl -sSfL https://release.solana.com/v1.18.18/install)"
            if ! grep -q 'solana' ~/.bashrc; then
                echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
                echo "已将 Solana 添加到 .bashrc 的 PATH 中。请重新启动终端或运行 'source ~/.bashrc' 以应用更改。"
            fi
            export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        else
            echo "Solana 已经安装。"
        fi
    }

    setup_wallet() {
        KEYPAIR_DIR="$HOME/solana_keypairs"
        mkdir -p "$KEYPAIR_DIR"

        echo "您想使用现有钱包还是创建新钱包？"
        PS3="请输入您的选择 (1 或 2)："
        options=("使用现有钱包" "创建新钱包")
        select opt in "${options[@]}"; do
            case $opt in
                "使用现有钱包")
                    echo "正在从现有钱包恢复..."
                    KEYPAIR_PATH="$KEYPAIR_DIR/eclipse-import.json"
                    solana-keygen recover -o "$KEYPAIR_PATH" --force
                    if [[ $? -ne 0 ]]; then
                        echo "恢复现有钱包失败。退出。"
                        exit 1
                    fi
                    break
                    ;;
                "创建新钱包")
                    echo "正在创建新钱包..."
                    KEYPAIR_PATH="$KEYPAIR_DIR/eclipse-new.json"
                    solana-keygen new -o "$KEYPAIR_PATH" --force
                    if [[ $? -ne 0 ]]; then
                        echo "创建新钱包失败。退出。"
                        exit 1
                    fi
                    break
                    ;;
                *) echo "无效选项。请重试。" ;;
            esac
        done

        solana config set --keypair "$KEYPAIR_PATH"
        echo "钱包设置完成！"
    }

    setup_network() {
        echo "您想在主网还是测试网部署？"
        PS3="请输入您的选择 (1 或 2)："
        network_options=("主网" "测试网")
        select network_opt in "${network_options[@]}"; do
            case $network_opt in
                "主网")
                    echo "设置为主网..."
                    NETWORK_URL="https://mainnetbeta-rpc.eclipse.xyz"
                    break
                    ;;
                "测试网")
                    echo "设置为测试网..."
                    NETWORK_URL="https://testnet.dev2.eclipsenetwork.xyz"
                    break
                    ;;
                *) echo "无效选项。请重试。" ;;
            esac
        done

        echo "正在设置 Solana 配置..."
        solana config set --url "$NETWORK_URL"
        echo "网络设置完成！"
    }

    # 执行各个步骤
    install_solana
    setup_wallet
    setup_network
}

create_spl_and_operations() {
    echo "正在创建 SPL 代币..."
    
    if ! solana config get | grep -q "Keypair Path:"; then
        echo "错误：在 Solana 配置中未设置密钥对。退出。"
        exit 1
    fi

    spl-token create-token --enable-metadata -p TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb
    if [[ $? -ne 0 ]]; then
        echo "创建 SPL 代币失败。退出。"
        exit 1
    fi

    read -p "请输入您在上面找到的代币地址： " TOKEN_ADDRESS
    read -p "请输入您的代币符号 (例如： ZUNXBT)： " TOKEN_SYMBOL
    read -p "请输入您的代币名称 (例如： Zenith Token)： " TOKEN_NAME
    read -p "请输入您的代币元数据网址： " METADATA_URL

    echo "正在初始化代币元数据..."
    spl-token initialize-metadata "$TOKEN_ADDRESS" "$TOKEN_NAME" "$TOKEN_SYMBOL" "$METADATA_URL"
    if [[ $? -ne 0 ]]; then
        echo "初始化代币元数据失败。退出。"
        exit 1
    fi

    echo "正在创建代币账户..."
    spl-token create-account "$TOKEN_ADDRESS"
    if [[ $? -ne 0 ]]; then
        echo "创建代币账户失败。退出。"
        exit 1
    fi

    echo "正在铸造代币..."
    spl-token mint "$TOKEN_ADDRESS" 10000
    if [[ $? -ne 0 ]]; then
        echo "铸造代币失败。退出。"
        exit 1
    fi

    echo "代币操作成功完成！"
}

private_key_conversion() {
    read -p "请输入您的私钥（例如：[内容]）： " private_key
    echo "private_key = $private_key" > sol.py
    echo "hex_key = ''.join(format(x, '02x') for x in private_key)" >> sol.py
    echo "print(hex_key)" >> sol.py

    echo "正在运行 python3 sol.py..."
    python3 sol.py
    echo "按任意键返回主菜单。"
    read -n 1 -s
}

main_menu() {
    while true; do
        clear
        echo "脚本由推特 @ferdie_jhovie 提供，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组: https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道: https://t.me/niuwuriji"
        echo "节点社区 Discord 社群: https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘 ctrl+c 退出"
        echo "请选择要执行的操作:"
        echo "1) 部署环境"
        echo "2) 创建 SPL 代币及操作"
        echo "3) 私钥转码"
        echo "4) 退出"

        read -p "请输入您的选择 (1-4): " choice
        case $choice in
            1) deploy_environment ;;
            2) create_spl_and_operations ;;
            3) private_key_conversion ;;
            4) echo "退出脚本。" ; exit 0 ;;
            *) echo "无效选项，请重试。" ;;
        esac
    done
}

main_menu
