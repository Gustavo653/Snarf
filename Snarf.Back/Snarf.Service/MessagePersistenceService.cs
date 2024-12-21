using Microsoft.EntityFrameworkCore;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;

namespace Snarf.Service
{
    public class MessagePersistenceService
    {
        private readonly IChatMessageRepository _chatMessageRepository;
        private readonly IUserRepository _userRepository;

        public MessagePersistenceService(IChatMessageRepository chatMessageRepository, IUserRepository userRepository)
        {
            _chatMessageRepository = chatMessageRepository;
            _userRepository = userRepository;
        }

        public async Task PersistMessageAsync(string senderUserId, string receiverUserId, string message)
        {
            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new ChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = message
            };

            await _chatMessageRepository.InsertAsync(chatMessage);
            await _chatMessageRepository.SaveChangesAsync();
        }
    }
}
