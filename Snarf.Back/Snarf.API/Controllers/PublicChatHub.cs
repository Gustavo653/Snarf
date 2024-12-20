using Microsoft.AspNetCore.SignalR;
using Serilog;

namespace Snarf.API.Controllers
{
    public class PublicChatHub : Hub
    {
        public async Task SendMessage(string message)
        {
            var userName = GetUserName();
            Log.Information($"Mensagem recebida de {userName}: {message}");
            await Clients.Others.SendAsync("ReceiveMessage", userName, message);
        }

        private string GetUserName()
        {
            return Context.User?.Identity?.Name ?? "Desconhecido";
        }

        public override async Task OnConnectedAsync()
        {
            var userName = GetUserName();
            Log.Information($"Cliente {userName} conectado ao chat público: {Context.ConnectionId}");
            await Clients.All.SendAsync("ReceiveMessage", userName, "Conectado");
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userName = GetUserName();
            Log.Information($"Cliente {userName} desconectado do chat público: {Context.ConnectionId}");
            await Clients.All.SendAsync("ReceiveMessage", userName, "Desconectado");
            await base.OnDisconnectedAsync(exception);
        }
    }
}