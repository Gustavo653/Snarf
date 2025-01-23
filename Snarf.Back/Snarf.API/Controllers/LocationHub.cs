using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;
using System.Collections.Concurrent;

namespace Snarf.API.Controllers
{
    public class LocationHub(IUserRepository _userRepository) : Hub
    {
        private static readonly ConcurrentDictionary<string, (double latitude, double longitude)> _userLocations = new();
        private static readonly ConcurrentDictionary<string, User> _users = new();

        public async Task UpdateLocation(double latitude, double longitude)
        {
            var userId = GetUserId();

            if (!_users.TryGetValue(userId, out var user))
            {
                user = await _userRepository.GetEntities()
                    .Where(x => x.Id == userId)
                    .FirstOrDefaultAsync();

                if (user != null)
                {
                    _users[userId] = user;
                }
                else
                {
                    throw new Exception($"Usuário não encontrado para {userId}");
                }
            }

            Log.Information($"Atualizando localização de {userId} ({user.Name}): ({latitude}, {longitude})");

            _userLocations[userId] = (latitude, longitude);

            await Clients.Others.SendAsync("ReceiveLocation", userId, latitude, longitude, user.Name, user.ImageUrl);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário conectado: {userId}");

            foreach (var userLocation in _userLocations)
            {
                if (!_users.TryGetValue(userLocation.Key, out var user))
                {
                    user = await _userRepository.GetEntities()
                        .Where(x => x.Id == userLocation.Key)
                        .FirstOrDefaultAsync();

                    if (user != null)
                    {
                        _users[userLocation.Key] = user;
                    }
                    else
                    {
                        throw new Exception($"Usuário não encontrado para {userId}");
                    }
                }

                await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Key, userLocation.Value.latitude, userLocation.Value.longitude, user.Name, user.ImageUrl);
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();

            if (exception != null)
            {
                Log.Warning($"Erro durante desconexão de {userId}: {exception.Message}");
            }
            else
            {
                Log.Information($"Usuário desconectado: {userId}");
            }

            _userLocations.TryRemove(userId, out _);
            _users.TryRemove(userId, out _);

            await Clients.Others.SendAsync("UserDisconnected", userId);

            await base.OnDisconnectedAsync(exception);
        }

        private string GetUserId()
        {
            var userId = Context.User?.GetUserId();
            if (userId == null)
            {
                Log.Error("O token não possui ID de usuário.");
                throw new ArgumentNullException("O token não possui ID de usuário");
            }

            return userId;
        }
    }
}