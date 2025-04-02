import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

typedef BuyConsumableCallback = void Function(ProductDetails productDetails);

class ConsumablePurchaseComponent extends StatelessWidget {
  final List<ProductDetails> consumableProducts;
  final BuyConsumableCallback onBuyConsumable;
  final int purchasedMinutes;

  const ConsumablePurchaseComponent({
    super.key,
    required this.consumableProducts,
    required this.onBuyConsumable,
    required this.purchasedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    if (consumableProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Nenhum produto avulso encontrado. Minutos extras: $purchasedMinutes',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Você comprou no total $purchasedMinutes minutos de video chamada.',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        for (final product in consumableProducts)
          Card(
            color: configProvider.secondaryColor,
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(
                product.description,
                style: TextStyle(
                  color: configProvider.textColor,
                ),
              ),
              trailing: Text(
                product.price,
                style: TextStyle(
                  color: configProvider.textColor,
                ),
              ),
              onTap: () => onBuyConsumable(product),
            ),
          ),
      ],
    );
  }
}
