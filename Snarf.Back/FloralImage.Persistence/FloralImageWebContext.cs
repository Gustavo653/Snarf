using FloralImage.Domain.Base;
using FloralImage.Domain.Entities;
using FloralImage.Domain.Location;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace FloralImage.Persistence
{
    public class FloralImageContext(DbContextOptions<FloralImageContext> options) : IdentityDbContext<User>(options)
    {
        public DbSet<InvoiceConfiguration> InvoiceConfigurations { get; set; }
        public DbSet<Invoice> Invoices { get; set; }
        public DbSet<InvoiceItem> InvoiceItems { get; set; }
        public DbSet<Product> Products { get; set; }
        public DbSet<CustomerXProduct> CustomerXProducts { get; set; }
        public DbSet<Customer> Customers { get; set; }
        public DbSet<State> States { get; set; }
        public DbSet<City> Cities { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<InvoiceConfiguration>(x =>
            {
            });

            modelBuilder.Entity<State>(x =>
            {
                x.HasIndex(a => new { a.Code }).IsUnique();
            });

            modelBuilder.Entity<City>(x =>
            {
                x.HasIndex(a => new { a.Code }).IsUnique();
            });
        }
    }
}