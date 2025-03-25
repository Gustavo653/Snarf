import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/config_provider.dart';

class CallOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    return Consumer<CallManager>(
      builder: (context, callManager, child) {
        if (callManager.isCallOverlayVisible) {
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: kToolbarHeight + 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: config.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Chamada recebida de ${callManager.incomingCallerName}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: config.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: callManager.acceptCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.call,
                            color: config.iconColor,
                          ),
                          label: Text(
                            "Atender",
                            style: TextStyle(
                              color: config.iconColor,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: callManager.rejectCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.call_end,
                            color: config.iconColor,
                          ),
                          label: Text(
                            "Recusar",
                            style: TextStyle(
                              color: config.iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (callManager.isCallRejectedOverlayVisible) {
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: kToolbarHeight + 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: config.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Chamada rejeitada",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: config.textColor,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      callManager.callRejectionReason,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: config.textColor,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        callManager.closeRejectionOverlay();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config.customRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: config.iconColor,
                      ),
                      label: Text(
                        "OK",
                        style: TextStyle(
                          color: config.iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
