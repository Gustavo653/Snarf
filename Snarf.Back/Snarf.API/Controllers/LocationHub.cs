using Microsoft.AspNetCore.SignalR;
using Serilog;
using System.Collections.Concurrent;

namespace Snarf.API.Controllers
{
    public class LocationHub : Hub
    {
        private static readonly ConcurrentDictionary<string, (double latitude, double longitude)> _userLocations = new();

        public async Task UpdateLocation(double latitude, double longitude)
        {
            Log.Information($"Atualizando localização de {Context.ConnectionId}: ({latitude}, {longitude})");

            _userLocations[Context.ConnectionId] = (latitude, longitude);

            await Clients.Others.SendAsync("ReceiveLocation", latitude, longitude);
        }

        public override async Task OnConnectedAsync()
        {
            Log.Information($"Cliente conectado: {Context.ConnectionId}");

            foreach (var userLocation in _userLocations)
            {
                await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Value.latitude, userLocation.Value.longitude);
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var connectionId = Context.ConnectionId;
            Log.Information($"Cliente desconectado: {connectionId}");

            if (exception != null)
            {
                Log.Warning($"Erro durante desconexão de {connectionId}: {exception.Message}");
            }

            _userLocations.TryRemove(connectionId, out var userLocation);

            await Clients.Others.SendAsync("UserDisconnected", userLocation.latitude, userLocation.longitude);

            await base.OnDisconnectedAsync(exception);
        }
    }
}