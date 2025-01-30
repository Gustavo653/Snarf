using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Entities;
using Snarf.DTO;
using Snarf.Infrastructure.Repository;
using Snarf.Service;
using Snarf.Utils;
using System.Collections.Concurrent;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class SnarfHub(
        IUserRepository _userRepository,
        IPublicChatMessageRepository _publicChatMessageRepository,
        IPrivateChatMessageRepository _privateChatMessageRepository,
        IBlockedUserRepository _blockedUserRepository) : Hub
    {
        private static ConcurrentDictionary<string, List<string>> _userConnections = new();

        public async Task SendMessage(string jsonMessage)
        {
            var message = SignalRMessage.Deserialize(jsonMessage);

            switch (message.Type)
            {
                case nameof(SignalREventType.MapUpdateLocation):
                    await HandleMapUpdateLocation(message.Data);
                    break;
                case nameof(SignalREventType.PublicChatSendMessage):
                    await HandlePublicChatSendMessage(message.Data);
                    break;
                case nameof(SignalREventType.PublicChatDeleteMessage):
                    await HandlePublicChatDeleteMessage(message.Data);
                    break;
                case nameof(SignalREventType.PublicChatGetPreviousMessages):
                    await HandlePublicChatGetPreviousMessages();
                    break;
                case nameof(SignalREventType.PrivateChatSendMessage):
                    await HandlePrivateChatSendMessage(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatGetRecentChats):
                    await HandlePrivateChatGetRecentChats();
                    break;
                case nameof(SignalREventType.PrivateChatGetPreviousMessages):
                    await HandlePrivateChatGetPreviousMessages(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatMarkMessagesAsRead):
                    await HandlePrivateChatMarkMessagesAsRead(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatDeleteMessage):
                    await HandlePrivateChatDeleteMessage(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatDeleteChat):
                    await HandlePrivateChatDeleteChat(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatSendImage):
                    await HandlePrivateChatSendImage(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatSendAudio):
                    await HandlePrivateChatSendAudio(message.Data);
                    break;
                case nameof(SignalREventType.PrivateChatSendVideo):
                    await HandlePrivateChatSendVideo(message.Data);
                    break;

                default:
                    Log.Warning($"Evento desconhecido recebido: {message.Type}");
                    break;
            }
        }

        private async Task HandleMapUpdateLocation(JsonElement data)
        {
            var userId = GetUserId();
            var location = JsonSerializer.Deserialize<LocationModel>(data.ToString());

            var user = await _userRepository.GetTrackedEntities()
                .Where(x => x.Id == userId)
                .FirstOrDefaultAsync();

            if (user == null) return;

            user.LastActivity = DateTime.UtcNow;
            user.LastLatitude = location.Latitude;
            user.LastLongitude = location.Longitude;
            await _userRepository.SaveChangesAsync();

            Log.Information($"Localização atualizada: {userId} - ({location.Latitude}, {location.Longitude})");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.MapReceiveLocation, new
            {
                userId,
                Latitude = location.Latitude,
                Longitude = location.Longitude,
                user.Name,
                userImage = user.ImageUrl
            });

            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePublicChatSendMessage(JsonElement data)
        {
            var userId = GetUserId();
            var text = data.GetProperty("Message").GetString();
            if (string.IsNullOrWhiteSpace(text)) return;

            var user = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == userId);

            if (user == null) return;

            var message = new PublicChatMessage
            {
                SenderId = userId,
                Message = text
            };

            await _publicChatMessageRepository.InsertAsync(message);
            await _publicChatMessageRepository.SaveChangesAsync();

            var blockedUsers = await _blockedUserRepository
                .GetEntities()
                .Where(b => b.Blocked.Id == userId)
                .Select(b => b.Blocker.Id)
                .ToListAsync();

            var blockedConnectionIds = new List<string>();

            foreach (var blockedUserId in blockedUsers)
            {
                if (_userConnections.TryGetValue(blockedUserId, out var connections))
                {
                    blockedConnectionIds.AddRange(connections);
                }
            }

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessage, new
            {
                message.Id,
                CreatedAt = DateTime.UtcNow,
                UserId = userId,
                UserName = user.Name,
                UserImage = user.ImageUrl,
                Latitude = user.LastLatitude,
                Longitude = user.LastLongitude,
                Message = text
            });

            await Clients.AllExcept(blockedConnectionIds).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePublicChatDeleteMessage(JsonElement data)
        {
            var userId = GetUserId();
            var messageId = data.GetProperty("MessageId").GetString();

            var message = await _publicChatMessageRepository
                .GetTrackedEntities()
                .FirstOrDefaultAsync(m => m.Id == Guid.Parse(messageId))
                ?? throw new Exception("Mensagem não encontrada.");

            if (message.SenderId != userId)
                throw new Exception("Você não pode excluir mensagens de outro usuário.");

            message.Message = "Mensagem excluída";

            await _publicChatMessageRepository.SaveChangesAsync();
            Log.Information($"Mensagem {message.Id} do usuário {userId} marcada como excluída.");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessageDeleted, new
            {
                MessageId = message.Id,
                Message = "Mensagem excluída"
            });

            await Clients.All.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePublicChatGetPreviousMessages()
        {
            var userId = GetUserId();
            var previousMessages = await _publicChatMessageRepository
                .GetEntities()
                .Where(x => !x.Sender.BlockedBy.Select(x => x.Blocker.Id).Contains(userId))
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
                .OrderBy(m => m.CreatedAt)
                .Select(x => new
                {
                    x.Id,
                    CreatedAt = x.CreatedAt.ToUniversalTime(),
                    UserId = x.Sender.Id,
                    UserName = x.Sender.Name,
                    UserImage = x.Sender.ImageUrl,
                    Latitude = x.Sender.LastLatitude,
                    Longitude = x.Sender.LastLongitude,
                    x.Message
                })
                .ToListAsync();

            foreach (var message in previousMessages)
            {
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessage, message);
                await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
            }
        }

        private async Task HandlePrivateChatSendMessage(JsonElement data)
        {
            var senderUserId = GetUserId();
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var messageText = data.GetProperty("Message").GetString();

            if (string.IsNullOrWhiteSpace(messageText)) return;

            var senderUser = await _userRepository
                .GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == senderUserId);

            if (senderUser == null) return;

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = messageText,
                IsRead = false
            };

            chatMessage.SetCreatedAt(DateTime.UtcNow);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                CreatedAt = chatMessage.CreatedAt,
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = messageText
            });
            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatGetRecentChats()
        {
            var userId = GetUserId();
            var messages = await _privateChatMessageRepository.GetEntities()
                .Where(m => m.Sender.Id == userId || m.Receiver.Id == userId)
                .Select(m => new
                {
                    SenderId = m.Sender.Id,
                    SenderName = m.Sender.Name,
                    SenderImage = m.Sender.ImageUrl,
                    ReceiverId = m.Receiver.Id,
                    ReceiverName = m.Receiver.Name,
                    ReceiverImage = m.Receiver.ImageUrl,
                    m.Message,
                    m.CreatedAt,
                    m.IsRead,
                })
                .ToListAsync();

            var recentChats = messages
                .GroupBy(m => m.ReceiverId == userId ? m.SenderId : m.ReceiverId)
                .Select(group => new
                {
                    UserId = group.Key,
                    UserName = group.First().ReceiverId == userId ? group.First().SenderName : group.First().ReceiverName,
                    UserImage = group.First().ReceiverId == userId ? group.First().SenderImage : group.First().ReceiverImage,
                    LastMessage = group.OrderByDescending(m => m.CreatedAt).First().Message,
                    LastMessageDate = group.Max(m => m.CreatedAt),
                    UnreadCount = group.Count(m => m.ReceiverId == userId && !m.IsRead)
                })
                .OrderByDescending(c => c.LastMessageDate)
                .ToList();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveRecentChats, recentChats);
            await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatGetPreviousMessages(JsonElement data)
        {
            var userId = GetUserId();
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();

            var previousMessages = await _privateChatMessageRepository.GetEntities()
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .Select(x => new
                {
                    x.Id,
                    CreatedAt = x.CreatedAt.ToUniversalTime(),
                    SenderId = x.Sender.Id,
                    ReceiverId = x.Receiver.Id,
                    x.Message
                })
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
                .OrderBy(m => m.CreatedAt)
                .ToListAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceivePreviousMessages, previousMessages);
            await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatDeleteMessage(JsonElement data)
        {
            var messageId = data.GetProperty("MessageId").GetString();
            var userId = GetUserId();

            var message = await _privateChatMessageRepository
                .GetTrackedEntities()
                .Include(x => x.Receiver)
                .Include(x => x.Sender)
                .FirstOrDefaultAsync(m => m.Id.ToString() == messageId);

            if (message == null)
            {
                Log.Warning($"Mensagem {messageId} não encontrada para exclusão pelo usuário {userId}");
                throw new Exception("Mensagem não encontrada");
            }

            if (message.Sender.Id != userId && message.Receiver.Id != userId)
            {
                Log.Warning($"Usuário {userId} tentou excluir mensagem {messageId} sem permissão");
                throw new UnauthorizedAccessException("Você não tem permissão para excluir esta mensagem");
            }

            if (message.Message.StartsWith("https://"))
            {
                var s3Service = new S3Service();
                await s3Service.DeleteFileAsync(message.Message);
            }

            message.Message = "Mensagem excluída";
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu a mensagem {messageId}");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessageDeleted, new
            {
                MessageId = messageId,
            });
            await Clients.User(message.Sender.Id).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(message.Receiver.Id).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatDeleteChat(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var userId = GetUserId();
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Include(x => x.Sender)
                .Include(x => x.Receiver)
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .ToListAsync();
            foreach (var message in messages)
            {
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessageDeleted, new
                {
                    MessageId = message.Id,
                });
                await Clients.User(message.Sender.Id).SendAsync("ReceiveMessage", jsonResponse);
                await Clients.User(message.Receiver.Id).SendAsync("ReceiveMessage", jsonResponse);
                if (message.Message.StartsWith("https://"))
                {
                    var s3Service = new S3Service();
                    await s3Service.DeleteFileAsync(message.Message);
                }
                else
                {
                    _privateChatMessageRepository.Delete(message);
                }
            }
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu o chat com {receiverUserId}");
        }

        private async Task HandlePrivateChatSendImage(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var imageBase64 = data.GetProperty("Image").GetString();
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();
            var senderUserName = Context.User?.Identity?.Name ?? "Desconhecido";

            Log.Information($"Usuário {senderUserId} enviou uma imagem para {receiverUserId}.");

            var imageBytes = Convert.FromBase64String(imageBase64);
            var imageStream = new MemoryStream(imageBytes);
            var s3Service = new S3Service();
            var imageUrl = await s3Service.UploadFileAsync($"images/{fileName}{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = imageUrl,
                IsRead = false
            };

            chatMessage.SetCreatedAt(DateTime.UtcNow);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = imageUrl
            });
            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatMarkMessagesAsRead(JsonElement data)
        {
            var senderUserId = data.GetProperty("SenderUserId").GetString();
            var receiverUserId = GetUserId();
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Where(m => m.Sender.Id == senderUserId && m.Receiver.Id == receiverUserId && !m.IsRead)
                .ToListAsync();

            Log.Information($"Usuário {receiverUserId} leu {messages.Count} de {senderUserId}");

            foreach (var message in messages)
            {
                message.IsRead = true;
            }

            await _privateChatMessageRepository.SaveChangesAsync();
        }

        private async Task HandlePrivateChatSendAudio(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var audioBase64 = data.GetProperty("Audio").GetString();   // Chave "Audio" ao invés de "Image"
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
                throw new Exception("Usuário não encontrado");

            // Decodificando e enviando para o S3
            var audioBytes = Convert.FromBase64String(audioBase64);
            var audioStream = new MemoryStream(audioBytes);
            var s3Service = new S3Service();
            var audioUrl = await s3Service.UploadFileAsync(
                $"audios/{fileName}{Guid.NewGuid()}",
                audioStream,
                "audio/mpeg"  // MimeType para áudio
            );

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = audioUrl,   // O Message vai receber o URL do áudio
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.UtcNow);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = audioUrl
            });

            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatSendVideo(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var videoBase64 = data.GetProperty("Video").GetString();   // Chave "Video"
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
                throw new Exception("Usuário não encontrado");

            // Decodificando e enviando para o S3
            var videoBytes = Convert.FromBase64String(videoBase64);
            var videoStream = new MemoryStream(videoBytes);
            var s3Service = new S3Service();
            var videoUrl = await s3Service.UploadFileAsync(
                $"videos/{fileName}{Guid.NewGuid()}",
                videoStream,
                "video/mp4"   // MimeType para vídeo
            );

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = videoUrl,  // O Message vai receber o URL do vídeo
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.UtcNow);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = videoUrl
            });

            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} conectado");

            if (_userConnections.TryGetValue(userId, out var connections))
            {
                connections.Add(Context.ConnectionId);
            }
            else
            {
                _userConnections[userId] = new List<string> { Context.ConnectionId };
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} desconectado");

            if (_userConnections.TryGetValue(userId, out var connections))
            {
                connections.Remove(Context.ConnectionId);
                if (connections.Count == 0)
                {
                    _userConnections.TryRemove(userId, out _);
                }
            }

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.UserDisconnected, new { userId });
            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);

            await base.OnDisconnectedAsync(exception);
        }

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        private class LocationModel
        {
            public double Latitude { get; set; }
            public double Longitude { get; set; }
        }
    }
}