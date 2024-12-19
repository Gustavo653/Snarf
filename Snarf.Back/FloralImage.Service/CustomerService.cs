using CsvHelper.Configuration;
using CsvHelper;
using FloralImage.Domain.Entities;
using FloralImage.Domain.Enum;
using FloralImage.DTO;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using Microsoft.EntityFrameworkCore;
using Serilog;
using System.Globalization;
using System.Text;
using FloralImage.Utils;

namespace FloralImage.Service
{
    public class CustomerService(
        ICustomerRepository customerRepository,
        IProductRepository productRepository,
        ICustomerXProductRepository customerXProductRepository,
        IStateRepository stateRepository,
        ICityRepository cityRepository,
        IInvoiceRepository invoiceRepository) : ICustomerService
    {
        public async Task<ResponseDTO> Create(CustomerDTO customerDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var state = await stateRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == customerDTO.StateId);
                if (state == null)
                {
                    responseDTO.SetBadInput($"O estado {customerDTO.StateId} não existe!");
                    return responseDTO;
                }

                var city = await cityRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == customerDTO.CityId);
                if (city == null)
                {
                    responseDTO.SetBadInput($"A cidade {customerDTO.CityId} não existe!");
                    return responseDTO;
                }

                if (customerDTO.ReferenceEndDate <= customerDTO.ReferenceStartDate)
                {
                    responseDTO.SetBadInput($"Verifique as datas do período de referência");
                    return responseDTO;
                }

                var customer = new Customer()
                {
                    ContractStartDate = customerDTO.ContractStartDate,
                    Number = customerDTO.Number,
                    Document = customerDTO.Document,
                    Name = customerDTO.Name,
                    CompanyName = customerDTO.CompanyName,
                    Address = customerDTO.Address,
                    PostalCode = customerDTO.PostalCode,
                    City = city,
                    State = state,
                    Email = customerDTO.Email,
                    AdditionalInfo = customerDTO.AdditionalInfo,
                    CustomerInvoiceDate = customerDTO.CustomerInvoiceDate,
                    BillDueDate = customerDTO.BillDueDate,
                    InvoiceGenerationOption = customerDTO.InvoiceGenerationOption,
                    BillingStatus = customerDTO.BillingStatus,
                    ReferenceStartDate = customerDTO.ReferenceStartDate,
                    ReferenceEndDate = customerDTO.ReferenceEndDate,
                };

                var customerXProducts = new List<CustomerXProduct>();

                if (customerDTO.Products != null)
                {
                    foreach (var item in customerDTO.Products)
                    {
                        var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == item.Id);
                        if (product == null)
                        {
                            Log.Warning($"O produto com id {item} não foi encontrado");
                            continue;
                        }
                        customerXProducts.Add(new CustomerXProduct() { Customer = customer, Product = product, Quantity = item.Quantity, Price = item.Price });
                    }
                    customerXProductRepository.AttachRange(customerXProducts);
                }

                await customerRepository.InsertAsync(customer);

                await customerRepository.SaveChangesAsync();
                Log.Information("Cliente persistido id: {id}", customer.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Update(Guid id, CustomerDTO customerDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var customer = await customerRepository.GetTrackedEntities().Include(x => x.CustomerXProducts).FirstOrDefaultAsync(c => c.Id == id);
                if (customer == null)
                {
                    responseDTO.SetBadInput($"O cliente {customerDTO.Document} não existe!");
                    return responseDTO;
                }

                var state = await stateRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == customerDTO.StateId);
                if (state == null)
                {
                    responseDTO.SetBadInput($"O estado {customerDTO.StateId} não existe!");
                    return responseDTO;
                }

                var city = await cityRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == customerDTO.CityId);
                if (city == null)
                {
                    responseDTO.SetBadInput($"A cidade {customerDTO.CityId} não existe!");
                    return responseDTO;
                }

                if (customerDTO.ReferenceEndDate <= customerDTO.ReferenceStartDate)
                {
                    responseDTO.SetBadInput($"Verifique as datas do período de referência");
                    return responseDTO;
                }

                customer.ContractStartDate = customerDTO.ContractStartDate;
                customer.Number = customerDTO.Number;
                customer.Name = customerDTO.Name;
                customer.CompanyName = customerDTO.CompanyName;
                customer.Address = customerDTO.Address;
                customer.Document = customerDTO.Document;
                customer.PostalCode = customerDTO.PostalCode;
                customer.City = city;
                customer.State = state;
                customer.Email = customerDTO.Email;
                customer.AdditionalInfo = customerDTO.AdditionalInfo;
                customer.CustomerInvoiceDate = customerDTO.CustomerInvoiceDate;
                customer.BillDueDate = customerDTO.BillDueDate;
                customer.InvoiceGenerationOption = customerDTO.InvoiceGenerationOption;
                customer.BillingStatus = customerDTO.BillingStatus;
                customer.ReferenceStartDate = customerDTO.ReferenceStartDate;
                customer.ReferenceEndDate = customerDTO.ReferenceEndDate;
                customer.SetUpdatedAt();

                if (customer.CustomerXProducts != null && customer.CustomerXProducts.Any())
                    customerXProductRepository.DeleteRange(customer.CustomerXProducts.ToArray());

                var customerXProducts = new List<CustomerXProduct>();

                if (customerDTO.Products != null)
                {
                    foreach (var item in customerDTO.Products)
                    {
                        var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == item.Id);
                        if (product == null)
                        {
                            Log.Warning($"O produto com id {item} não foi encontrado");
                            continue;
                        }
                        customerXProducts.Add(new CustomerXProduct() { Customer = customer, Product = product, Quantity = item.Quantity, Price = item.Price });
                    }
                    customerXProductRepository.AttachRange(customerXProducts);
                }

                await customerRepository.SaveChangesAsync();
                Log.Information("Cliente persistido id: {id}", customer.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Remove(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var customer = await customerRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == id);
                if (customer == null)
                {
                    responseDTO.SetBadInput($"O cliente com id: {id} não existe!");
                    return responseDTO;
                }

                var customerHasInvoices = await invoiceRepository.GetEntities().Where(x => x.Customer == customer).AnyAsync();
                if (customerHasInvoices)
                {
                    responseDTO.SetBadInput($"O cliente possui faturas e não pode ser removido!");
                    return responseDTO;
                }

                customerRepository.Delete(customer);
                await customerRepository.SaveChangesAsync();
                Log.Information("Cliente removida id: {id}", customer.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetList()
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await customerRepository.GetEntities()
                                                             .Select(x => new
                                                             {
                                                                 x.Id,
                                                                 x.Number,
                                                                 x.Name,
                                                                 BillingStatus = x.BillingStatus == BillingStatus.Active ? "Ativo" :
                                                                                 x.BillingStatus == BillingStatus.Inactive ? "Inativo" :
                                                                                 "Pausado",
                                                                 Products = string.Join(", ",
                                                                     x.CustomerXProducts
                                                                      .GroupBy(p => p.Product.Name)
                                                                      .Select(g => $"{g.Key} ({g.Sum(p => p.Quantity)})"))
                                                             })
                                                             .OrderByDescending(x => x.Number)
                                                             .ToListAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetCustomerById(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await customerRepository.GetEntities()
                                                             .Select(x => new
                                                             {
                                                                 x.Id,
                                                                 x.CompanyName,
                                                                 x.Name,
                                                                 x.Document,
                                                                 x.Number,
                                                                 x.Email,
                                                                 x.AdditionalInfo,
                                                                 x.PostalCode,
                                                                 x.Address,
                                                                 x.CreatedAt,
                                                                 x.UpdatedAt,
                                                                 CityId = x.City.Id,
                                                                 StateId = x.State.Id,
                                                                 x.CustomerInvoiceDate,
                                                                 x.BillDueDate,
                                                                 x.InvoiceGenerationOption,
                                                                 x.ReferenceStartDate,
                                                                 x.ReferenceEndDate,
                                                                 x.BillingStatus,
                                                                 x.ContractStartDate,
                                                                 products = x.CustomerXProducts.Select(x => new
                                                                 {
                                                                     ItemId = x.Id,
                                                                     ProductId = x.Product.Id,
                                                                     ProductPrice = x.Price,
                                                                     ProductTotalPrice = x.Price * x.Quantity,
                                                                     ProductName = x.Product.Name,
                                                                     ProductQuantity = x.Quantity,
                                                                     x.CreatedAt,
                                                                     x.UpdatedAt
                                                                 }),
                                                             }).FirstOrDefaultAsync(x => x.Id == id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetDashboardCustomers()
        {
            ResponseDTO responseDTO = new();
            try
            {
                var summary = await customerRepository.GetEntities()
                    .GroupBy(x => x.BillingStatus)
                    .Select(group => new
                    {
                        BillingStatus = group.Key == BillingStatus.Active ? "Ativo" :
                                        group.Key == BillingStatus.Inactive ? "Inativo" :
                                        "Pausado",
                        CustomerCount = group.Count(),
                        ProductsCount = group.SelectMany(c => c.CustomerXProducts).Sum(x => x.Quantity)
                    })
                    .ToListAsync();

                var totalCustomers = summary.Sum(x => x.CustomerCount);
                var totalProducts = summary.Sum(x => x.ProductsCount);

                summary.Add(new
                {
                    BillingStatus = "Todos",
                    CustomerCount = totalCustomers,
                    ProductsCount = totalProducts
                });

                responseDTO.Object = summary;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }


        public async Task ImportarClientesCSV()
        {
            string filePath = "C:\\Users\\Gustavo\\Documents\\lista.csv";

            var config = new CsvConfiguration(CultureInfo.GetCultureInfo("pt-BR"))
            {
                Delimiter = ";",
                HasHeaderRecord = true,
                MissingFieldFound = null,
                BadDataFound = null
            };

            using var reader = new StreamReader(filePath, Encoding.Latin1);
            using var csv = new CsvReader(reader, config);
            csv.Context.RegisterClassMap<ClienteMap>();

            var records = csv.GetRecords<Cliente>().ToList();

            foreach (var cliente in records)
            {
                cliente.ValorTotalP = cliente.ValorTotalP.Replace("R$", "");
                cliente.ValorTotalM = cliente.ValorTotalM.Replace("R$", "");
                cliente.ValorTotalG = cliente.ValorTotalG.Replace("R$", "");
                cliente.Email = cliente.Email ?? "Sem contato";
                cliente.DataVencimentoBoleto = cliente.DataVencimentoBoleto.Replace("cash", "25");
                cliente.EmiteSomenteFatura = cliente.EmiteSomenteFatura.Replace("X", "InvoiceOnly");

                Console.WriteLine($"Processando cliente {cliente.NumeroCadastro}");

                var customerExists = await customerRepository.GetEntities().AnyAsync(x => x.Number == cliente.NumeroCadastro);
                if (customerExists)
                    continue;

                var state = await stateRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Abbreviation == cliente.Estado);
                var city = await cityRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Name == cliente.Cidade);

                var customer = new Customer()
                {
                    ContractStartDate = DateTime.Parse(cliente.ClienteDesde),
                    Address = cliente.Endereco,
                    BillDueDate = DateTime.UtcNow,
                    CustomerInvoiceDate = Convert.ToInt32(cliente.DataEmissaoBoleto.ToString()),
                    AdditionalInfo = cliente.Comentario,
                    BillingStatus = cliente.StatusCliente == "Ativo" ? BillingStatus.Active : cliente.StatusCliente == "Pausado" ? BillingStatus.Paused : BillingStatus.Inactive,
                    CompanyName = cliente.RazaoSocialOuNome,
                    Document = cliente.CpfOuCnpj,
                    Email = cliente.Email,
                    InvoiceGenerationOption = cliente.EmiteSomenteFatura == "InvoiceOnly" ? InvoiceGenerationOption.InvoiceOnly : InvoiceGenerationOption.InvoiceAndBankSlip,
                    Name = cliente.NomeDeCadastro,
                    Number = cliente.NumeroCadastro,
                    PostalCode = cliente.Cep,
                    State = state,
                    City = city,
                    ReferenceEndDate = DateTime.UtcNow,
                    ReferenceStartDate = DateTime.UtcNow,
                    CustomerXProducts = new List<CustomerXProduct>()
                };
                await customerRepository.InsertAsync(customer);

                if (cliente.QtdP.HasValue)
                {
                    var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Name.ToLower().Contains("pequeno"));
                    var customerxproduct = new CustomerXProduct()
                    {
                        Customer = customer,
                        Product = product,
                        Price = Convert.ToDecimal(cliente.ValorTotalP.ToString()) / Convert.ToDecimal(cliente.QtdP),
                        Quantity = Convert.ToInt32(cliente.QtdP)
                    };
                    await customerXProductRepository.InsertAsync(customerxproduct);
                }
                if (cliente.QtdM.HasValue)
                {
                    var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Name.ToLower().Contains("médio"));
                    var customerxproduct = new CustomerXProduct()
                    {
                        Customer = customer,
                        Product = product,
                        Price = Convert.ToDecimal(cliente.ValorTotalM.ToString()) / Convert.ToDecimal(cliente.QtdM),
                        Quantity = Convert.ToInt32(cliente.QtdM)
                    };
                    await customerXProductRepository.InsertAsync(customerxproduct);
                }
                if (cliente.QtdG.HasValue)
                {
                    var product = await productRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Name.ToLower().Contains("grande"));
                    var customerxproduct = new CustomerXProduct()
                    {
                        Customer = customer,
                        Product = product,
                        Price = Convert.ToDecimal(cliente.ValorTotalG.ToString()) / Convert.ToDecimal(cliente.QtdG),
                        Quantity = Convert.ToInt32(cliente.QtdG)
                    };
                    await customerXProductRepository.InsertAsync(customerxproduct);
                }

                await customerRepository.SaveChangesAsync();
                Console.WriteLine($"Cliente processado {cliente.CpfOuCnpj}");
            }
        }

        public async Task<string> GenerateReport()
        {
            var customers = await customerRepository.GetEntities()
                .Select(x => new
                {
                    NumeroCadastro = x.Number,
                    NomeDeCadastro = x.Name,
                    RazaoSocial = x.CompanyName,
                    Documento = x.Document,
                    Endereco = x.Address,
                    Cidade = x.City.Name,
                    Estado = x.State.Name,
                    CEP = x.PostalCode,
                    Email = x.Email,
                    QtdP = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("pequeno")).Sum(x => x.Quantity),
                    QtdM = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("médio")).Sum(x => x.Quantity),
                    QtdG = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("grande")).Sum(x => x.Quantity),
                    QtdTotal = x.CustomerXProducts.Sum(x => x.Quantity),
                    PrecoP = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("pequeno")).Sum(x => x.Price * x.Quantity),
                    PrecoM = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("médio")).Sum(x => x.Price * x.Quantity),
                    PrecoG = x.CustomerXProducts.Where(p => p.Product.Name.ToLower().Contains("grande")).Sum(x => x.Price * x.Quantity),
                    PrecoTotal = x.CustomerXProducts.Sum(x => x.Price * x.Quantity),
                    DataVencimentoBoleto = x.BillDueDate,
                    ClienteDesde = x.ContractStartDate,
                    DataDeEmissaoBoleto = x.CustomerInvoiceDate,
                    OpcaoGeracaoFatura = x.InvoiceGenerationOption.GetDescription(),
                    StatusCliente = x.BillingStatus.GetDescription(),
                    ProximoPeriodoDeFaturamento = $"{x.ReferenceStartDate:dd/MM/yyyy} - {x.ReferenceEndDate:dd/MM/yyyy}",
                })
                .ToListAsync();

            using var writer = new StringWriter();
            using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                Delimiter = ";"
            });
            csv.WriteRecords(customers);
            return writer.ToString();
        }
    }

    public class Cliente
    {
        public int NumeroCadastro { get; set; }
        public string NomeDeCadastro { get; set; }
        public string RazaoSocialOuNome { get; set; }
        public string CpfOuCnpj { get; set; }
        public string Endereco { get; set; }
        public string ClienteDesde { get; set; }
        public string Cidade { get; set; }
        public string Estado { get; set; }
        public string Cep { get; set; }
        public string Email { get; set; }
        public int? QtdP { get; set; }
        public int? QtdM { get; set; }
        public int? QtdG { get; set; }
        public string? ValorTotalP { get; set; }
        public string? ValorTotalM { get; set; }
        public string? ValorTotalG { get; set; }
        public string? DataVencimentoBoleto { get; set; }
        public string? DataEmissaoBoleto { get; set; }
        public string? EmiteSomenteFatura { get; set; }
        public string StatusCliente { get; set; }
        public string? Comentario { get; set; }
    }

    public class ClienteMap : ClassMap<Cliente>
    {
        public ClienteMap()
        {
            Map(m => m.NumeroCadastro).Name("Número cadastro");
            Map(m => m.NomeDeCadastro).Name("Nome de Cadastro");
            Map(m => m.RazaoSocialOuNome).Name("Razão Social / Nome");
            Map(m => m.CpfOuCnpj).Name("CPF/CNPJ");
            Map(m => m.Endereco).Name("Endereço");
            Map(m => m.ClienteDesde).Name("Cliente desde");
            Map(m => m.Cidade).Name("Cidade");
            Map(m => m.Estado).Name("Estado");
            Map(m => m.Cep).Name("CEP");
            Map(m => m.Email).Name("e-mail");
            Map(m => m.QtdP).Name("QTD P");
            Map(m => m.QtdM).Name("QTD M");
            Map(m => m.QtdG).Name("QTD G");
            Map(m => m.ValorTotalP).Name("Valor Total P");
            Map(m => m.ValorTotalM).Name("Valor Total M");
            Map(m => m.ValorTotalG).Name("Valor Total G");
            Map(m => m.DataVencimentoBoleto).Name("Data vencimento boleto");
            Map(m => m.DataEmissaoBoleto).Name("Data de emissão boleto");
            Map(m => m.EmiteSomenteFatura).Name("Emite somente fatura");
            Map(m => m.StatusCliente).Name("Status Cliente");
            Map(m => m.Comentario).Name("Comentário");
        }
    }
}
