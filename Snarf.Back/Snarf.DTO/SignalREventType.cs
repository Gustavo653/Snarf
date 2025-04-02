namespace Snarf.DTO
{
    public enum SignalREventType
    {
        UserConnected,
        UserDisconnected,

        MapUpdateLocation,
        MapReceiveLocation,

        PublicChatSendMessage,
        PublicChatReceiveMessage,
        PublicChatDeleteMessage,
        PublicChatReceiveMessageDeleted,
        PublicChatGetPreviousMessages,

        PartyChatSendMessage,
        PartyChatReceiveMessage,
        PartyChatDeleteMessage,
        PartyChatReceiveMessageDeleted,
        PartyChatGetPreviousMessages,

        PrivateChatSendMessage,
        PrivateChatReceiveMessage,
        PrivateChatGetRecentChats,
        PrivateChatReceiveRecentChats,
        PrivateChatGetPreviousMessages,
        PrivateChatReceivePreviousMessages,
        PrivateChatMarkMessagesAsRead,
        PrivateChatDeleteMessage,
        PrivateChatDeleteChat,
        PrivateChatSendImage,
        PrivateChatSendVideo,
        PrivateChatSendAudio,
        PrivateChatReceiveMessageDeleted,

        PrivateChatGetFavorites,
        PrivateChatReceiveFavorites,
        PrivateChatAddFavorite,
        PrivateChatRemoveFavorite,

        PrivateChatReactToMessage,
        PrivateChatReceiveReaction,
        PrivateChatReplyToMessage,
        PrivateChatReceiveReply,

        VideoCallInitiate,
        VideoCallIncoming,
        VideoCallAccept,
        VideoCallReject,
        VideoCallCanceled,
        VideoCallEnd,
    }
}
