using System;
using System.ComponentModel;

namespace FloralImage.Domain.Enum
{
    public enum InvoiceStatus
    {
        [Description("Aberto")]
        Open,

        [Description("Cancelado")]
        Cancelled,

        [Description("Faturado")]
        Billed,

        [Description("Pago")]
        Paid,

        [Description("Faturando")]
        Billing
    }
}