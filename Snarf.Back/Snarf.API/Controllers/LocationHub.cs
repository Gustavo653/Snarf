using Microsoft.AspNetCore.SignalR;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Utils;
using System.Collections.Concurrent;

namespace Snarf.API.Controllers
{
    public class LocationHub : Hub
    {
        private static readonly ConcurrentDictionary<string, (double latitude, double longitude)> _userLocations = new();

        public async Task UpdateLocation(double latitude, double longitude)
        {
            var userId = GetUserId();

            Log.Information($"Atualizando localização de {userId}: ({latitude}, {longitude})");

            _userLocations[userId] = (latitude, longitude);

            await Clients.Others.SendAsync("ReceiveLocation", userId, latitude, longitude);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário conectado: {userId}");

            foreach (var userLocation in _userLocations)
            {
                await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Key, userLocation.Value.latitude, userLocation.Value.longitude);
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();

            Log.Information($"Usuário desconectado: {userId}");

            if (exception != null)
            {
                Log.Warning($"Erro durante desconexão de {userId}: {exception.Message}");
            }

            _userLocations.TryRemove(userId, out _);

            await Clients.Others.SendAsync("UserDisconnected", userId);

            await base.OnDisconnectedAsync(exception);
        }

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }
    }
}