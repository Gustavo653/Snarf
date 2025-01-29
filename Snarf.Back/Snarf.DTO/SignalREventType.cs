using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Snarf.DTO
{
    public enum SignalREventType
    {
        UpdateLocation,
        ReceiveLocation,
        UserDisconnected,
        SendMessage,
        ReceiveMessage,
        DeleteMessage,
        ReceiveMessageDeleted,
        GetPreviousMessages
    }
}
