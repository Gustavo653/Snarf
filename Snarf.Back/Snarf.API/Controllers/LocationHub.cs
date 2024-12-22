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
        private static readonly ConcurrentDictionary<string, string> _userNamesCache = new(); // Cache de nomes

        public async Task UpdateLocation(double latitude, double longitude)
        {
            var userId = GetUserId();

            if (!_userNamesCache.TryGetValue(userId, out var userName))
            {
                userName = await _userRepository.GetEntities()
                    .Where(x => x.Id == userId)
                    .Select(x => x.Name)
                    .FirstOrDefaultAsync();

                if (userName != null)
                {
                    _userNamesCache[userId] = userName;
                }
                else
                {
                    Log.Warning($"Nome de usuário não encontrado para {userId}");
                    userName = "Desconhecido";
                }
            }

            Log.Information($"Atualizando localização de {userId} ({userName}): ({latitude}, {longitude})");

            _userLocations[userId] = (latitude, longitude);

            await Clients.Others.SendAsync("ReceiveLocation", userId, latitude, longitude, userName);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário conectado: {userId}");

            foreach (var userLocation in _userLocations)
            {
                if (!_userNamesCache.TryGetValue(userLocation.Key, out var userName))
                {
                    userName = await _userRepository.GetEntities()
                        .Where(x => x.Id == userLocation.Key)
                        .Select(x => x.Name)
                        .FirstOrDefaultAsync();

                    if (userName != null)
                    {
                        _userNamesCache[userLocation.Key] = userName;
                    }
                    else
                    {
                        userName = "Desconhecido";
                    }
                }

                await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Key, userLocation.Value.latitude, userLocation.Value.longitude, userName);
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
            _userNamesCache.TryRemove(userId, out _);

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