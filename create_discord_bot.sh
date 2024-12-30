#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ASCII Art
echo -e "${PURPLE}"
cat << "EOF"
╔═══════════════════════════════════════╗
║  ____  _                       _      ║
║ |  _ \(_)___  ___ ___  _ __ _| |      ║
║ | | | | / __|/ __/ _ \| '__/_  |      ║
║ | |_| | \__ \ (_| (_) | | / _| |      ║
║ |____/|_|___/\___\___/|_| /____|      ║
║          Bot Creator Pro              ║
║         By Enyzelle ⭐️ v2.1           ║
╚═══════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}Choose your preferred programming language:${NC}"
echo -e "${YELLOW}1. ${GREEN}JavaScript ${YELLOW}(Node.js)${NC}"
echo -e "${YELLOW}2. ${BLUE}Python${NC}"
echo -e -n "${PURPLE}Enter your choice (1 or 2): ${NC}"
read choice

case $choice in
    1)
        echo -e "${GREEN}Creating JavaScript Discord bot...${NC}"
        echo -e -n "${CYAN}Enter your bot name: ${NC}"
        read botname
        mkdir "$botname"
        cd "$botname"

        # Initialize npm and install dependencies
        npm init -y
        npm install discord.js dotenv fs path @discordjs/rest @discordjs/builders @discordjs/voice

        # Create directory structure
        mkdir -p src/{commands,events,handlers}

        # Create config file
        cat > config.json << EOL
{
    "prefix": "!",
    "clientId": "your_client_id_here",
    "guildId": ""
}
EOL

        # Create main bot file
        cat > src/index.js << EOL
const { Client, GatewayIntentBits, Collection } = require('discord.js');
const { loadEvents } = require('./handlers/eventHandler');
const { loadCommands } = require('./handlers/commandHandler');
const { prefix } = require('../config.json');
const dotenv = require('dotenv');

dotenv.config();

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.GuildVoiceStates
    ]
});

client.commands = new Collection();
client.slashCommands = new Collection();

client.on('messageCreate', async (message) => {
    if (message.author.bot || !message.content.startsWith(prefix)) return;

    const args = message.content.slice(prefix.length).trim().split(/ +/);
    const commandName = args.shift().toLowerCase();

    const command = client.commands.get(commandName);
    if (!command) return;

    try {
        await command.messageExecute(message, args);
    } catch (error) {
        console.error(error);
        message.reply('There was an error executing that command!');
    }
});

client.on('interactionCreate', async (interaction) => {
    if (!interaction.isCommand()) return;

    const command = client.slashCommands.get(interaction.commandName);
    if (!command) return;

    try {
        await command.execute(interaction);
    } catch (error) {
        console.error(error);
        await interaction.reply({ 
            content: 'There was an error executing this command!', 
            ephemeral: true 
        });
    }
});

loadEvents(client);
loadCommands(client);

client.login(process.env.TOKEN);
EOL

        # Create event handler
        cat > src/handlers/eventHandler.js << EOL
const fs = require('fs');
const path = require('path');

function loadEvents(client) {
    const eventsPath = path.join(__dirname, '../events');
    const eventFiles = fs.readdirSync(eventsPath).filter(file => file.endsWith('.js'));

    for (const file of eventFiles) {
        const event = require(path.join(eventsPath, file));
        if (event.once) {
            client.once(event.name, (...args) => event.execute(...args));
        } else {
            client.on(event.name, (...args) => event.execute(...args));
        }
    }
}

module.exports = { loadEvents };
EOL

        # Create command handler
        cat > src/handlers/commandHandler.js << EOL
const fs = require('fs');
const path = require('path');
const { REST } = require('@discordjs/rest');
const { Routes } = require('discord.js');
const { clientId, guildId } = require('../../config.json');

function loadCommands(client) {
    const commands = [];
    const commandsPath = path.join(__dirname, '../commands');
    const commandFiles = fs.readdirSync(commandsPath).filter(file => file.endsWith('.js'));

    for (const file of commandFiles) {
        const command = require(path.join(commandsPath, file));
        
        // Register regular commands
        if (command.name) {
            client.commands.set(command.name, command);
        }
        
        // Register slash commands
        if (command.data) {
            client.slashCommands.set(command.data.name, command);
            commands.push(command.data.toJSON());
        }
    }

    const rest = new REST({ version: '10' }).setToken(process.env.TOKEN);

    (async () => {
        try {
            console.log('Started refreshing application (/) commands.');

            if (guildId) {
                // Guild specific commands - instant update, good for testing
                await rest.put(
                    Routes.applicationGuildCommands(clientId, guildId),
                    { body: commands },
                );
                console.log('Successfully registered guild commands.');
            } else {
                // Global commands - can take up to 1 hour to update
                await rest.put(
                    Routes.applicationCommands(clientId),
                    { body: commands },
                );
                console.log('Successfully registered global commands.');
            }

        } catch (error) {
            console.error(error);
        }
    })();
}

module.exports = { loadCommands };
EOL

        # Create example event
        cat > src/events/ready.js << EOL
module.exports = {
    name: 'ready',
    once: true,
    execute(client) {
        console.log(\`🚀 \${client.user.tag} is online and ready!\`);
        client.user.setActivity('with Discord.js', { type: 'PLAYING' });
    },
};
EOL

        # Create example command
        cat > src/commands/ping.js << EOL
const { SlashCommandBuilder } = require('discord.js');

module.exports = {
    name: 'ping',
    description: 'Replies with bot latency',
    data: new SlashCommandBuilder()
        .setName('ping')
        .setDescription('Replies with bot latency'),
    async execute(interaction) {
        const sent = await interaction.reply({ content: 'Pinging...', fetchReply: true });
        const latency = sent.createdTimestamp - interaction.createdTimestamp;
        await interaction.editReply(\`Pong! 🏓\nBot Latency: \${latency}ms\nWebSocket Latency: \${interaction.client.ws.ping}ms\`);
    },
    async messageExecute(message) {
        const sent = await message.reply('Pinging...');
        const latency = sent.createdTimestamp - message.createdTimestamp;
        await sent.edit(\`Pong! 🏓\nBot Latency: \${latency}ms\nWebSocket Latency: \${message.client.ws.ping}ms\`);
    }
};
EOL

        # Create .env file
        cat > .env << EOL
TOKEN=your_discord_bot_token_here
EOL

        # Create README
        cat > README.md << EOL
# 🤖 $botname Discord Bot

## ✨ Features
- Advanced command & event handler
- Flexible slash commands (guild-specific or global)
- Message commands support
- Modern Discord.js v14
- Organized file structure

## 🚀 Setup
1. Install dependencies: \`npm install\`
2. Configure \`.env\` and \`config.json\`
3. Run the bot: \`node src/index.js\`

## ⚙️ Configuration
- In \`config.json\`:
  - Set \`clientId\` to your bot's application ID
  - For testing: Add \`guildId\` for instant command updates in a specific server
  - For production: Leave \`guildId\` empty for global commands (takes up to 1 hour to update)

## 📁 File Structure
\`\`\`
$botname/
├── src/
│   ├── commands/
│   ├── events/
│   ├── handlers/
│   └── index.js
├── config.json
├── .env
└── package.json
\`\`\`

## 🛠️ Development
- Add new commands in \`src/commands/\`
- Add new events in \`src/events/\`
- Configure bot settings in \`config.json\`

## 💡 Slash Commands
- For development: Set \`guildId\` to test commands instantly in your server
- For production: Remove \`guildId\` to register commands globally
- Global commands take up to 1 hour to update but work in all servers
EOL

        echo -e "${GREEN}JavaScript Discord bot created successfully! 🎉${NC}"
        echo -e "${CYAN}Don't forget to:${NC}"
        echo -e "${YELLOW}1. Add your bot token to .env file${NC}"
        echo -e "${YELLOW}2. Configure clientId and guildId in config.json${NC}"
        echo -e "${YELLOW}3. Run 'npm install' to install dependencies${NC}"
        echo -e "${YELLOW}4. Start the bot with 'node src/index.js'${NC}"
        ;;

    2)
        echo -e "${BLUE}Creating Python Discord bot...${NC}"
        echo -e -n "${CYAN}Enter your bot name: ${NC}"
        read botname
        mkdir "$botname"
        cd "$botname"

        # Create virtual environment
        python3 -m venv venv

        # Create directory structure
        mkdir -p cogs utils

        # Create requirements.txt
        cat > requirements.txt << EOL
discord.py
python-dotenv
aiohttp
wavelink
EOL

        # Create main bot file
        cat > bot.py << EOL
import os
import discord
from discord.ext import commands
from dotenv import load_dotenv
import asyncio
import logging
from utils.config import Config

# Setup logging
logging.basicConfig(level=logging.INFO)

# Load environment variables
load_dotenv()

class Bot(commands.Bot):
    def __init__(self):
        super().__init__(
            command_prefix=commands.when_mentioned_or(Config.PREFIX),
            intents=discord.Intents.all(),
            help_command=None
        )
        self.config = Config

    async def setup_hook(self):
        # Load cogs
        for filename in os.listdir('./cogs'):
            if filename.endswith('.py'):
                try:
                    await self.load_extension(f'cogs.{filename[:-3]}')
                    logging.info(f'Loaded cog: {filename[:-3]}')
                except Exception as e:
                    logging.error(f'Failed to load cog {filename[:-3]}: {str(e)}')
        
        # Sync commands with Discord
        await self.tree.sync()
        logging.info("Synced application commands")

    async def on_ready(self):
        logging.info(f'🚀 Logged in as {self.user} (ID: {self.user.id})')
        await self.change_presence(activity=discord.Game(name=f'{self.config.PREFIX}help'))

async def main():
    bot = Bot()
    async with bot:
        await bot.start(os.getenv('TOKEN'))

if __name__ == '__main__':
    asyncio.run(main())
EOL

        # Create config file
        cat > utils/config.py << EOL
class Config:
    PREFIX = "!"
    OWNER_IDS = []  # Add owner IDs here
    STARTUP_COGS = [
        "cogs.general",
        "cogs.admin",
        "cogs.events"
    ]
    # Add more configuration options here
EOL

        # Create general cog
        cat > cogs/general.py << EOL
import discord
from discord import app_commands
from discord.ext import commands
import time

class General(commands.Cog):
    def __init__(self, bot):
        self.bot = bot

    @commands.hybrid_command(name="ping", description="Check the bot's latency")
    async def ping(self, ctx):
        start_time = time.time()
        message = await ctx.send("Pinging...")
        end_time = time.time()

        embed = discord.Embed(title="🏓 Pong!", color=discord.Color.green())
        embed.add_field(
            name="Bot Latency",
            value=f"{round((end_time - start_time) * 1000)}ms",
            inline=True
        )
        embed.add_field(
            name="WebSocket Latency",
            value=f"{round(self.bot.latency * 1000)}ms",
            inline=True
        )

        await message.edit(content=None, embed=embed)

async def setup(bot):
    await bot.add_cog(General(bot))
EOL

        # Create events cog
        cat > cogs/events.py << EOL
import discord
from discord.ext import commands
import logging

class Events(commands.Cog):
    def __init__(self, bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_command_error(self, ctx, error):
        if isinstance(error, commands.CommandNotFound):
            return
        elif isinstance(error, commands.MissingPermissions):
            await ctx.send("You don't have permission to use this command!")
        else:
            logging.error(f'Error: {str(error)}')

async def setup(bot):
    await bot.add_cog(Events(bot))
EOL

        # Create .env file
        cat > .env << EOL
TOKEN=your_discord_bot_token_here
EOL

        # Create README
        cat > README.md << EOL
# 🤖 $botname Discord Bot

## ✨ Features
- Modern discord.py structure
- Cog-based command system
- Hybrid commands (slash + prefix)
- Advanced error handling
- Clean project structure

## 🚀 Setup
1. Create virtual environment: \`python3 -m venv venv\`
2. Activate virtual environment:
   - Windows: \`venv\\Scripts\\activate\`
   - Unix/MacOS: \`source venv/bin/activate\`
3. Install dependencies: \`pip install -r requirements.txt\`
4. Configure \`.env\` with your bot token
5. Run the bot: \`python bot.py\`

## 📁 File Structure
\`\`\`
$botname/
├── cogs/
│   ├── general.py
│   └── events.py
├── utils/
│   └── config.py
├── bot.py
├── .env
└── requirements.txt
\`\`\`

## 🛠️ Development
- Add new cogs in \`cogs/\`
- Configure bot settings in \`utils/config.py\`
- Handle events in \`cogs/events.py\`
EOL

        echo -e "${GREEN}Python Discord bot created successfully! 🎉${NC}"
        echo -e "${CYAN}Don't forget to:${NC}"
        echo -e "${YELLOW}1. Add your bot token to .env file${NC}"
        echo -e "${YELLOW}2. Create and activate virtual environment${NC}"
        echo -e "${YELLOW}3. Install requirements with 'pip install -r requirements.txt'${NC}"
        echo -e "${YELLOW}4. Start the bot with 'python bot.py'${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again and select 1 or 2.${NC}"
        exit 1
        ;;
esac
