using CsvHelper;
using CsvHelper.Configuration;
using FloralImage.Domain.Entities;
using FloralImage.Domain.Enum;
using FloralImage.DTO;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Hangfire;
using iText.IO.Image;
using iText.Kernel.Colors;
using iText.Kernel.Pdf;
using iText.Kernel.Pdf.Canvas.Draw;
using iText.Layout;
using iText.Layout.Element;
using iText.Layout.Properties;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
using System.IO.Compression;
using System.Net.Mail;
using System.Text;

namespace FloralImage.Service
{
    public class InvoiceService(
        ICustomerRepository customerRepository,
        IInvoiceConfigurationRepository invoiceConfigurationRepository,
        IProductRepository productRepository,
        IInvoiceItemRepository invoiceItemRepository,
        IInvoiceRepository invoiceRepository,
        ISantanderService santanderService,
        IEmailService emailService) : IInvoiceService
    {
        public async Task<ResponseDTO> BillInvoice(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var invoice = await invoiceRepository.GetTrackedEntities().Include(x => x.Customer).FirstOrDefaultAsync(x => x.Id == id);
                if (invoice == null)
                {
                    responseDTO.SetBadInput($"Não foi encontrada uma fatura com id {id}");
                    return responseDTO;
                }

                var invoiceConfiguration = await invoiceConfigurationRepository.GetEntities().AnyAsync();
                if (!invoiceConfiguration)
                {
                    responseDTO.SetBadInput($"Nenhuma configuração de fatura encontrada");
                    return responseDTO;
                }

                var nextNumber = await invoiceConfigurationRepository.GetAndIncrementNextNumberAsync();

                if (invoice.InvoiceStatus != InvoiceStatus.Open)
                {
                    responseDTO.SetBadInput($"A fatura não pode ser faturada, pois o status {invoice.InvoiceStatus} é inválido");
                    return responseDTO;
                }

                var jobId = BackgroundJob.Schedule(() => santanderService.CreateBankSlip(invoice.Id), TimeSpan.FromSeconds(30));
                BackgroundJob.ContinueJobWith(jobId, () => SendInvoiceEmail(invoice.Id, nextNumber, invoice.Customer.Email));

                invoice.Customer.SetBillAndReferenceDates();

                invoice.InvoiceStatus = InvoiceStatus.Billing;
                invoice.Number = nextNumber;
                invoice.IssueDate = DateTime.UtcNow;
                await invoiceRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task SendInvoiceEmail(Guid invoiceId, int nextNumber, string recipient)
        {
            var attachments = new List<Attachment>();
            var invoice = await invoiceRepository.GetEntities().Include(x => x.Customer).FirstOrDefaultAsync(x => x.Id == invoiceId);
            var invoiceBytes = await GeneratePdfByInvoiceId(invoiceId);
            var body = emailService.BuildInvoiceEmail(nextNumber);

            var invoiceAttachment = new Attachment(new MemoryStream(invoiceBytes), $"{invoice.Number}. {invoice.Customer.Name} - {invoice.IssueDate:MM-yyyy} - fatura.pdf", "application/pdf");

            if (invoice.Customer.InvoiceGenerationOption == InvoiceGenerationOption.InvoiceAndBankSlip)
            {
                var bankSlipBytes = await santanderService.GetPDFBankSlip(invoiceId);
                var bankSlipAttachment = new Attachment(new MemoryStream(bankSlipBytes), $"{invoice.Number}. {invoice.Customer.Name} - {invoice.IssueDate:MM-yyyy} - boleto.pdf", "application/pdf");
                attachments.Add(bankSlipAttachment);
            }

            attachments.Add(invoiceAttachment);

            await emailService.SendEmail($"{invoice.Customer.Name} - Faturamento plano de assinatura de flores", body, recipient, attachments);
        }

        public async Task<ResponseDTO> CancelInvoice(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var invoice = await invoiceRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id);
                if (invoice == null)
                {
                    responseDTO.SetBadInput($"Não foi encontrada uma fatura com id {id}");
                    return responseDTO;
                }

                if (invoice.InvoiceStatus == InvoiceStatus.Paid)
                {
                    responseDTO.SetBadInput($"A fatura não pode ser cancelada, pois o status {invoice.InvoiceStatus} é inválido");
                    return responseDTO;
                }

                BackgroundJob.Enqueue(() => santanderService.CancelBankSlip(invoice.Id));

                invoice.InvoiceStatus = InvoiceStatus.Cancelled;
                await invoiceRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetInvoices(DateTime startDate, DateTime endDate)
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await invoiceRepository.GetEntities()
                                                            .Where(x => x.IssueDate.Date >= startDate.Date && x.IssueDate.Date <= endDate.Date)
                                                            .Select(x => new
                                                            {
                                                                x.Id,
                                                                x.Number,
                                                                x.InvoiceStatus,
                                                                InvoiceStatusStringValue = x.InvoiceStatus.GetDescription(),
                                                                x.IssueDate,
                                                                CustomerName = x.Customer.Name,
                                                                InvoiceTotal = x.InvoiceItems.Sum(x => x.Price * x.Quantity),
                                                            }).OrderByDescending(x => x.Number)
                                                              .ThenByDescending(x => x.IssueDate)
                                                              .ToListAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task GenerateInvoicesByCustomers()
        {
            var today = DateTime.Today;
            var lastDayOfMonth = DateTime.DaysInMonth(today.Year, today.Month);

            var customers = await customerRepository
                .GetTrackedEntities()
                .Include(x => x.CustomerXProducts).ThenInclude(x => x.Product)
                .Where(x => x.BillingStatus == BillingStatus.Active &&
                            (x.CustomerInvoiceDate <= lastDayOfMonth ? x.CustomerInvoiceDate : lastDayOfMonth) == today.Day &&
                            !x.Invoices.Any(y => y.IssueDate.Year == today.Year &&
                                                 y.IssueDate.Month == today.Month))
                .ToListAsync();

            foreach (var customer in customers)
            {
                var invoice = new Invoice()
                {
                    Customer = customer,
                    InvoiceItems = [],
                    InvoiceStatus = InvoiceStatus.Open,
                    IssueDate = DateTime.UtcNow,
                    ReferenceStartDate = customer.ReferenceStartDate,
                    ReferenceEndDate = customer.ReferenceEndDate,
                };

                await invoiceRepository.InsertAsync(invoice);

                if (customer.CustomerXProducts != null && customer.CustomerXProducts.Count > 0)
                {
                    foreach (var customerXProduct in customer.CustomerXProducts)
                    {
                        var invoiceItem = new InvoiceItem()
                        {
                            Invoice = invoice,
                            Price = customerXProduct.Price,
                            Product = customerXProduct.Product,
                            Quantity = customerXProduct.Quantity,
                        };
                        await invoiceItemRepository.InsertAsync(invoiceItem);
                    }
                }

                if (customer.InvoiceGenerationOption == InvoiceGenerationOption.InvoiceAndBankSlip)
                {
                    invoice.BillDueDate = customer.BillDueDate;
                    //BackgroundJob.Enqueue(() => BillInvoice(invoice.Id));
                }
                await invoiceRepository.SaveChangesAsync();
            }
        }

        public async Task<ResponseDTO> GetInvoiceById(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await invoiceRepository.GetEntities()
                                                            .Select(x => new
                                                            {
                                                                x.Id,
                                                                x.Number,
                                                                x.InvoiceStatus,
                                                                InvoiceStatusStringValue = x.InvoiceStatus.GetDescription(),
                                                                x.IssueDate,
                                                                x.BillDueDate,
                                                                x.ReferenceStartDate,
                                                                x.ReferenceEndDate,
                                                                InvoiceItems = x.InvoiceItems.Select(x => new
                                                                {
                                                                    ItemId = x.Id,
                                                                    ProductId = x.Product.Id,
                                                                    ProductName = x.Product.Name,
                                                                    ProductTotalPrice = x.Price * x.Quantity,
                                                                    ProductPrice = x.Price,
                                                                    ProductQuantity = x.Quantity,
                                                                    x.CreatedAt,
                                                                    x.UpdatedAt
                                                                }),
                                                                CustomerId = x.Customer.Id,
                                                                CustomerName = x.Customer.Name,
                                                                InvoiceTotal = x.InvoiceItems.Sum(x => x.Price * x.Quantity),
                                                            }).FirstOrDefaultAsync(x => x.Id == id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> SaveInvoice(Guid? id, InvoiceDTO invoiceDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var invoice = await invoiceRepository.GetTrackedEntities().Include(x => x.InvoiceItems).FirstOrDefaultAsync(x => x.Id == id);
                var customer = await customerRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == invoiceDTO.CustomerId);
                if (customer == null)
                {
                    responseDTO.SetBadInput($"O cliente com id {invoiceDTO.CustomerId} não foi encontrado");
                    return responseDTO;
                }

                if (invoiceDTO.ReferenceEndDate <= invoiceDTO.ReferenceStartDate)
                {
                    responseDTO.SetBadInput($"Verifique as datas do período de referência");
                    return responseDTO;
                }

                if (invoice == null)
                {
                    invoice = new Invoice()
                    {
                        Customer = customer,
                        InvoiceItems = [],
                        InvoiceStatus = InvoiceStatus.Open,
                        IssueDate = invoiceDTO.IssueDate,
                        ReferenceStartDate = invoiceDTO.ReferenceStartDate,
                        ReferenceEndDate = invoiceDTO.ReferenceEndDate,
                        BillDueDate = invoiceDTO.BillDueDate,
                    };
                    await invoiceRepository.InsertAsync(invoice);
                }
                else
                {
                    if (invoice.InvoiceStatus != InvoiceStatus.Open)
                    {
                        responseDTO.SetBadInput($"A fatura está com status {invoice.InvoiceStatus} que é inválido");
                        return responseDTO;
                    }
                    invoice.Customer = customer;
                    invoice.IssueDate = invoiceDTO.IssueDate;
                    invoice.BillDueDate = invoiceDTO.BillDueDate;
                    invoice.SetUpdatedAt();
                }

                invoiceItemRepository.DeleteRange(invoice.InvoiceItems.ToArray());

                foreach (var item in invoiceDTO.InvoiceItems)
                {
                    var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == item.ProductId);
                    if (product == null)
                    {
                        responseDTO.SetBadInput($"O produto com id {item.ProductId} não foi encontrado");
                        return responseDTO;
                    }
                    var invoiceItem = new InvoiceItem()
                    {
                        Invoice = invoice,
                        Product = product,
                        Price = item.Price,
                        Quantity = item.Quantity,
                    };
                    await invoiceItemRepository.InsertAsync(invoiceItem);
                }
                await invoiceRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<byte[]> GeneratePdfByInvoiceId(Guid id)
        {
            using MemoryStream ms = new();

            var invoiceConfiguration = await invoiceConfigurationRepository.GetEntities()
                                                                           .Include(x => x.State)
                                                                           .Include(x => x.City)
                                                                           .FirstOrDefaultAsync()
                                                                           ?? throw new InvalidOperationException("Nenhuma configuração de fatura encontrada");
            var invoice = await invoiceRepository.GetEntities()
                                                 .Include(x => x.InvoiceItems).ThenInclude(x => x.Product)
                                                 .Include(x => x.Customer).ThenInclude(x => x.State)
                                                 .Include(x => x.Customer).ThenInclude(x => x.City)
                                                 .FirstOrDefaultAsync(x => x.Id == id)
                                                 ?? throw new InvalidOperationException($"A fatura {id} não existe ou não foi faturada");

            var writer = new PdfWriter(ms);
            var pdf = new PdfDocument(writer);
            var document = new Document(pdf);

            document.SetMargins(20, 20, 20, 20);

            string imagePath = Path.Combine(AppContext.BaseDirectory, "Image", "logo.jpg");
            var imageData = ImageDataFactory.Create(imagePath);
            var logo = new Image(imageData).ScaleToFit(80, 80);
            logo.SetFixedPosition(20, pdf.GetDefaultPageSize().GetTop() - 100);

            document.Add(logo);

            document.Add(new Paragraph("Fatura de Locação")
                .SetTextAlignment(TextAlignment.CENTER)
                .SetFontSize(18)
                .SimulateItalic()
                .SetFontColor(ColorConstants.DARK_GRAY));

            document.Add(new Paragraph($"Número da Fatura: {invoice.Number}")
                .SetTextAlignment(TextAlignment.RIGHT)
                .SetFontSize(10)
                .SimulateItalic()
                .SetFontColor(ColorConstants.GRAY));

            document.Add(new Paragraph($"Data de Emissão: {invoice.IssueDate:dd/MM/yyyy}")
                .SetTextAlignment(TextAlignment.RIGHT)
                .SetFontSize(10)
                .SimulateItalic()
                .SetFontColor(ColorConstants.GRAY));

            document.Add(new LineSeparator(new SolidLine()).SetMarginTop(10).SetMarginBottom(10));

            document.Add(new Paragraph("Locador").SimulateBold().SetFontSize(12));
            document.Add(new Paragraph($"Nome/Razão Social: {invoiceConfiguration.CompanyName} - CNPJ: {invoiceConfiguration.Document}").SetFontSize(10));
            document.Add(new Paragraph($"Endereço: {invoiceConfiguration.Address}, {invoiceConfiguration.City.Name}/{invoiceConfiguration.State.Name} - CEP: {invoiceConfiguration.PostalCode}").SetFontSize(10));
            document.Add(new Paragraph($"Email: {invoiceConfiguration.Email}").SetFontSize(10));

            document.Add(new LineSeparator(new SolidLine()).SetMarginTop(5).SetMarginBottom(5));

            document.Add(new Paragraph("Locatário").SimulateBold().SetFontSize(12));
            document.Add(new Paragraph($"Nome/Razão Social: {invoice.Customer.CompanyName} - CNPJ: {invoice.Customer.Document}").SetFontSize(10));
            document.Add(new Paragraph($"Endereço: {invoice.Customer.Address}, {invoice.Customer.City.Name}/{invoice.Customer.State.Name} - CEP: {invoice.Customer.PostalCode}").SetFontSize(10));
            document.Add(new Paragraph($"Email: {invoice.Customer.Email}").SetFontSize(10));

            document.Add(new LineSeparator(new SolidLine()).SetMarginTop(5).SetMarginBottom(5));

            document.Add(new Paragraph("Descrição dos Itens").SimulateBold().SetFontSize(12));
            var table = new Table(UnitValue.CreatePercentArray(new float[] { 40, 20, 20, 20 })).UseAllAvailableWidth();

            table.AddHeaderCell(new Cell().Add(new Paragraph("Descrição").SetFontSize(10).SimulateBold().SetFontColor(ColorConstants.WHITE)).SetBackgroundColor(ColorConstants.DARK_GRAY).SetTextAlignment(TextAlignment.CENTER));
            table.AddHeaderCell(new Cell().Add(new Paragraph("Quantidade").SetFontSize(10).SimulateBold().SetFontColor(ColorConstants.WHITE)).SetBackgroundColor(ColorConstants.DARK_GRAY).SetTextAlignment(TextAlignment.CENTER));
            table.AddHeaderCell(new Cell().Add(new Paragraph("Valor Unitário(R$)").SetFontSize(10).SimulateBold().SetFontColor(ColorConstants.WHITE)).SetBackgroundColor(ColorConstants.DARK_GRAY).SetTextAlignment(TextAlignment.CENTER));
            table.AddHeaderCell(new Cell().Add(new Paragraph("Valor Total(R$)").SetFontSize(10).SimulateBold().SetFontColor(ColorConstants.WHITE)).SetBackgroundColor(ColorConstants.DARK_GRAY).SetTextAlignment(TextAlignment.CENTER));

            foreach (var item in invoice.InvoiceItems)
            {
                table.AddCell(new Cell().Add(new Paragraph(item.Product.Name)).SetFontSize(10).SetTextAlignment(TextAlignment.LEFT));
                table.AddCell(new Cell().Add(new Paragraph(item.Quantity.ToString())).SetFontSize(10).SetTextAlignment(TextAlignment.CENTER));
                table.AddCell(new Cell().Add(new Paragraph($"R$ {item.Price:F2}")).SetFontSize(10).SetTextAlignment(TextAlignment.RIGHT));
                table.AddCell(new Cell().Add(new Paragraph($"R$ {item.Price * item.Quantity:F2}")).SetFontSize(10).SetTextAlignment(TextAlignment.RIGHT));
            }

            document.Add(table);

            var totalAmount = invoice.InvoiceItems.Sum(x => x.Quantity * x.Price);
            document.Add(new Paragraph($"Valor Total: R$ {totalAmount:F2}").SimulateBold().SetFontSize(10).SetTextAlignment(TextAlignment.RIGHT));
            if (!string.IsNullOrEmpty(invoice.Customer.AdditionalInfo))
            {
                document.Add(new LineSeparator(new SolidLine()).SetMarginTop(10).SetMarginBottom(10));
                document.Add(new Paragraph("Informações Adicionais").SimulateBold().SetFontSize(12));
                document.Add(new Paragraph(invoice.Customer.AdditionalInfo).SetFontSize(10).SimulateBold());

                document.Add(new Paragraph($"Referente ao período de {invoice.ReferenceStartDate:dd/MM/yyyy} até {invoice.ReferenceEndDate:dd/MM/yyyy}")
                    .SetFontSize(10)
                    .SimulateItalic());
            }

            document.Close();

            byte[] pdfBytes = ms.ToArray();
            return pdfBytes;
        }

        public async Task<string> GenerateReportByDate(DateTime startDate, DateTime endDate)
        {
            var invoices = await invoiceRepository.GetEntities()
                .Where(x => x.IssueDate.Date >= startDate.Date && x.IssueDate.Date <= endDate.Date)
                .Select(x => new
                {
                    NumeroFatura = x.Number,
                    NomeCadastro = x.Customer.CompanyName,
                    NomeRazaoSocial = x.Customer.Name,
                    CpfCnpj = x.Customer.Document,
                    ValorFaturado = x.InvoiceItems.Sum(y => y.Quantity * y.Price),
                    DataEmissao = x.IssueDate,
                    Status = x.InvoiceStatus.GetDescription()
                })
                .ToListAsync();

            using var writer = new StringWriter();
            using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                Delimiter = ";"
            });
            csv.WriteRecords(invoices);
            return writer.ToString();
        }

        public async Task ValidateBills()
        {
            var invoices = await invoiceRepository.GetTrackedEntities()
                                                  .Where(x => x.InvoiceStatus == InvoiceStatus.Billed && x.Customer.InvoiceGenerationOption == InvoiceGenerationOption.InvoiceAndBankSlip)
                                                  .Select(x => x.Id)
                                                  .ToListAsync();
            foreach (var item in invoices)
            {
                BackgroundJob.Enqueue(() => santanderService.CheckStatusBankSlip(item));
            }
        }

        public async Task<byte[]> GenerateZipPdfByDate(DateTime startDate, DateTime endDate)
        {
            var invoices = await invoiceRepository.GetEntities()
                                                  .Where(x => x.IssueDate.Date >= startDate.Date && x.IssueDate.Date <= endDate.Date)
                                                  .Select(x => new { x.Id, x.Customer.Name, x.Number, Date = x.IssueDate.ToString("MM-yyyy") })
                                                  .ToListAsync();

            using var memoryStream = new MemoryStream();
            using (var zipArchive = new ZipArchive(memoryStream, ZipArchiveMode.Create, true))
            {
                foreach (var invoice in invoices)
                {
                    var pdfBytes = await GeneratePdfByInvoiceId(invoice.Id);
                    var fileName = $"{invoice.Number}. {invoice.Name} - {invoice.Date} - fatura.pdf";
                    var zipEntry = zipArchive.CreateEntry(fileName, CompressionLevel.Fastest);
                    using var entryStream = zipEntry.Open();
                    await entryStream.WriteAsync(pdfBytes);
                }
            }

            return memoryStream.ToArray();
        }
    }
}