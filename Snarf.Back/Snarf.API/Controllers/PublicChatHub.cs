using Microsoft.AspNetCore.SignalR;
using Serilog;

namespace Snarf.API.Controllers
{
    public class PublicChatHub : Hub
    {
        public async Task SendMessage(string message)
        {
            Log.Information($"Mensagem recebida de {Context.ConnectionId}: {message}");
            await Clients.Others.SendAsync("ReceiveMessage", Context.ConnectionId, message);
        }

        public override async Task OnConnectedAsync()
        {
            Log.Information($"Cliente conectado ao chat público: {Context.ConnectionId}");
            await Clients.Others.SendAsync("ReceiveMessage", Context.ConnectionId, "Conectado");
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            Log.Information($"Cliente desconectado do chat público: {Context.ConnectionId}");
            await Clients.Others.SendAsync("ReceiveMessage", Context.ConnectionId, "Desconectado");
            await base.OnDisconnectedAsync(exception);
        }
    }
}