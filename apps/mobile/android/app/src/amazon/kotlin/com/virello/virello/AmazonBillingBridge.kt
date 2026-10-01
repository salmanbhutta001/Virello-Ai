package com.virello.virello

import android.content.Context
import com.amazon.device.iap.PurchasingListener
import com.amazon.device.iap.PurchasingService
import com.amazon.device.iap.model.FulfillmentResult
import com.amazon.device.iap.model.Product
import com.amazon.device.iap.model.ProductDataResponse
import com.amazon.device.iap.model.PurchaseResponse
import com.amazon.device.iap.model.PurchaseUpdatesResponse
import com.amazon.device.iap.model.Receipt
import com.amazon.device.iap.model.RequestId
import com.amazon.device.iap.model.UserDataResponse
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Amazon Appstore IAP v2 bridge — compiled ONLY in the `amazon` flavor.
 *
 * Dart side: lib/services/billing/amazon_billing.dart via
 * MethodChannel "virello/billing_amazon" + EventChannel
 * "virello/billing_amazon/events".
 *
 * Flow:
 *   getProducts(skus) -> ProductDataResponse -> list of BillingProduct maps
 *   purchase(sku)     -> PurchaseResponse (receipt) -> event on stream
 *   getPurchaseUpdates(reset) -> restores / missed purchases
 *   completePurchase(receiptId) -> notifyFulfillment(FULFILLED)
 *
 * Server verification (Amazon RVS) happens in our backend
 * (POST /api/v1/billing/amazon/verify) BEFORE we call
 * notifyFulfillment — the Dart layer enforces this ordering.
 */
class AmazonBillingBridge(
    context: Context,
    flutterEngine: FlutterEngine,
) : PurchasingListener {

    private val methodChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "virello/billing_amazon")
    private var eventSink: EventChannel.EventSink? = null

    private val pendingProductRequests = mutableMapOf<RequestId, MethodChannel.Result>()
    private val pendingUserData = mutableMapOf<RequestId, MethodChannel.Result>()
    private var lastUserId: String? = null
    private var lastMarketplace: String? = null

    init {
        PurchasingService.registerListener(context, this)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "virello/billing_amazon/events",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            },
        )

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    // PurchasingService exists on Fire OS / Amazon Appstore builds.
                    // Real availability is confirmed by a successful product query.
                    result.success(true)
                }
                "getProducts" -> {
                    @Suppress("UNCHECKED_CAST")
                    val skus = (call.argument<List<String>>("skus") ?: emptyList()).toSet()
                    val requestId = PurchasingService.getProductData(skus)
                    pendingProductRequests[requestId] = result
                }
                "getUserData" -> {
                    val requestId = PurchasingService.getUserData()
                    pendingUserData[requestId] = result
                }
                "purchase" -> {
                    val sku = call.argument<String>("sku")
                    if (sku.isNullOrEmpty()) {
                        result.error("ARG", "sku required", null)
                    } else {
                        PurchasingService.purchase(sku)
                        result.success(true)
                    }
                }
                "getPurchaseUpdates" -> {
                    val reset = call.argument<Boolean>("reset") ?: false
                    PurchasingService.getPurchaseUpdates(reset)
                    result.success(true)
                }
                "completePurchase" -> {
                    val receiptId = call.argument<String>("receiptId")
                    if (receiptId.isNullOrEmpty()) {
                        result.error("ARG", "receiptId required", null)
                    } else {
                        PurchasingService.notifyFulfillment(receiptId, FulfillmentResult.FULFILLED)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun emit(map: Map<String, Any?>) {
        eventSink?.success(map)
    }

    // ---- PurchasingListener ----

    override fun onUserDataResponse(response: UserDataResponse) {
        val userData = response.userData
        lastUserId = userData?.userId
        lastMarketplace = userData?.marketplace
        val payload = mapOf(
            "userId" to userData?.userId,
            "marketplace" to userData?.marketplace,
            "status" to response.requestStatus.toString(),
        )
        pendingUserData.remove(response.requestId)?.success(payload)
        emit(mapOf("type" to "userData") + payload)
    }

    override fun onProductDataResponse(response: ProductDataResponse) {
        val payload = mapOf(
            "status" to response.requestStatus.toString(),
            "unavailableSkus" to response.unavailableSkus.toList(),
            "products" to response.productData.values.map { p: Product ->
                mapOf(
                    "sku" to p.sku,
                    "title" to p.title,
                    "description" to p.description,
                    "price" to p.price,
                    "itemType" to p.productType.toString(),
                )
            },
        )
        pendingProductRequests.remove(response.requestId)?.success(payload)
    }

    override fun onPurchaseResponse(response: PurchaseResponse) {
        val receipt = response.receipt
        emit(
            mapOf(
                "type" to "purchase",
                "status" to response.requestStatus.toString(),
                "sku" to (receipt?.sku ?: response.requestId.toString()),
                "receiptId" to receipt?.receiptId,
                "userId" to (lastUserId ?: ""),
                "itemType" to (receipt?.productType?.toString() ?: ""),
                "purchaseDate" to (receipt?.purchaseDate?.time ?: 0L),
                "cancelDate" to (receipt?.cancelDate?.time ?: 0L),
            ),
        )
    }

    override fun onPurchaseUpdatesResponse(response: PurchaseUpdatesResponse) {
        val receipts = response.receipts.map { r: Receipt ->
            mapOf(
                "sku" to r.sku,
                "receiptId" to r.receiptId,
                "userId" to (lastUserId ?: ""),
                "itemType" to r.productType.toString(),
                "purchaseDate" to r.purchaseDate.time,
                "cancelDate" to (r.cancelDate?.time ?: 0L),
                "isCanceled" to r.isCanceled,
            )
        }
        emit(
            mapOf(
                "type" to "purchaseUpdates",
                "status" to response.requestStatus.toString(),
                "receipts" to receipts,
                "hasMore" to response.hasMore(),
            ),
        )
    }
}
