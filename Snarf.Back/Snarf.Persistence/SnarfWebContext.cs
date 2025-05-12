using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;

namespace Snarf.Persistence
{
    public class SnarfContext(DbContextOptions<SnarfContext> options) : IdentityDbContext<User>(options)
    {
        public DbSet<PrivateChatMessage> PrivateChatMessages { get; set; }
        public DbSet<PublicChatMessage> PublicChatMessages { get; set; }
        public DbSet<FavoriteChat> FavoriteChats { get; set; }
        public DbSet<BlockedUser> BlockedUsers { get; set; }
        public DbSet<VideoCallPurchase> VideoCallPurchases { get; set; }
        public DbSet<VideoCallLog> VideoCallLogs { get; set; }
        public DbSet<Party> Parties { get; set; }
        public DbSet<PartyChatMessage> PartyChatMessages { get; set; }
        public DbSet<Place> Places { get; set; }
        public DbSet<PlaceChatMessage> PlaceChatMessages { get; set; }
        public DbSet<PlaceVisitLog> PlaceVisitLogs { get; set; }
        public DbSet<UserPhoto> UserPhotos { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>()
                .HasMany(u => u.Photos)
                 .WithOne(p => p.User)
                 .HasForeignKey(p => p.UserId);

            modelBuilder.Entity<UserPhoto>(x =>
            {
                x.ToTable(t => t.HasCheckConstraint("CK_UserPhoto_Order", "Order BETWEEN 1 AND 4"));
                x.HasIndex(x => new { x.UserId, x.Order }).IsUnique();
            });

            modelBuilder.Entity<BlockedUser>()
                .HasOne(b => b.Blocker)
                .WithMany(u => u.BlockedUsers);

            modelBuilder.Entity<BlockedUser>()
                .HasOne(b => b.Blocked)
                .WithMany(u => u.BlockedBy);

            modelBuilder.Entity<FavoriteChat>()
                .HasOne(b => b.User)
                .WithMany(u => u.FavoriteChats);

            modelBuilder.Entity<FavoriteChat>()
                .HasOne(b => b.ChatUser)
                .WithMany(u => u.FavoritedBy);

            modelBuilder.Entity<VideoCallPurchase>()
                .HasOne(x => x.User)
                .WithMany(u => u.VideoCallPurchases)
                .HasForeignKey(x => x.UserId);

            modelBuilder.Entity<Party>()
                .HasOne(p => p.Owner)
                .WithMany(u => u.OwnedParties)
                .HasForeignKey(p => p.OwnerId);

            modelBuilder.Entity<Party>()
                .HasMany(p => p.InvitedUsers)
                .WithMany(u => u.Invitations)
                .UsingEntity<Dictionary<string, object>>(
                    "PartyInvitedUsers",
                    j => j.HasOne<User>().WithMany().HasForeignKey("UserId"),
                    j => j.HasOne<Party>().WithMany().HasForeignKey("PartyId")
                );

            modelBuilder.Entity<Party>()
                .HasMany(p => p.ConfirmedUsers)
                .WithMany(u => u.ConfirmedParties)
                .UsingEntity<Dictionary<string, object>>(
                    "PartyConfirmedUsers",
                    j => j.HasOne<User>().WithMany().HasForeignKey("UserId"),
                    j => j.HasOne<Party>().WithMany().HasForeignKey("PartyId")
                );
        }
    }
}