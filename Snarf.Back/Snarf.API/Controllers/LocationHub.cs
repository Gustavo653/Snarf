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

            await Clients.Others.SendAsync("ReceiveLocation", Context.ConnectionId, latitude, longitude);
        }

        public async Task RegisterConnectionId(string connectionId)
        {
            var currentConnectionId = Context.ConnectionId;

            if (_userLocations.TryRemove(connectionId, out var location))
            {
                _userLocations[currentConnectionId] = location;
                Log.Information($"ConnectionId atualizado de {connectionId} para {currentConnectionId}");
                await Clients.Others.SendAsync("ReceiveLocation", currentConnectionId, location.latitude, location.longitude);
            }
            else
            {
                Log.Warning($"Tentativa de atualização falhou: ConnectionId {connectionId} não encontrado.");
            }

            await Clients.All.SendAsync("UserDisconnected", connectionId);
        }


        public override async Task OnConnectedAsync()
        {
            Log.Information($"Cliente conectado: {Context.ConnectionId}");

            foreach (var userLocation in _userLocations)
            {
                await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Key, userLocation.Value.latitude, userLocation.Value.longitude);
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

            await Clients.Others.SendAsync("UserDisconnected", connectionId);

            await base.OnDisconnectedAsync(exception);
        }
    }
}