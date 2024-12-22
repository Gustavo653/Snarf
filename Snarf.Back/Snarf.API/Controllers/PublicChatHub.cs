using Microsoft.AspNetCore.SignalR;
using Serilog;
using Snarf.Utils;

namespace Snarf.API.Controllers
{
    public class PublicChatHub : Hub
    {
        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        private string GetUserName()
        {
            return Context.User?.GetUserName() ?? throw new ArgumentNullException("O token não possui nome de usuário");
        }

        public async Task SendMessage(string message)
        {
            var userId = GetUserId();
            Log.Information($"Mensagem recebida do usuário {userId}: {message}");
            await Clients.Others.SendAsync("ReceiveMessage", GetUserName(), message);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            Log.Information($"Cliente do usuário {userId} conectado ao chat público");

            await Clients.All.SendAsync("ReceiveMessage", GetUserName(), "Conectado");

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            if (exception != null)
                Log.Warning($"Erro durante desconexão do usuário {userId}: {exception.Message}");
            else
                Log.Information($"Usuário {userId} desconectado do chat público");

            await Clients.All.SendAsync("ReceiveMessage", GetUserName(), "Desconectado");

            await base.OnDisconnectedAsync(exception);
        }
    }
}