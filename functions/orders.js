const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ============================================================
// CONFIG - change these if your Firestore names are different
// ============================================================
const REGION = 'asia-northeast3';

const COL = {
  products: 'products',
  resellerProducts: 'reseller_products', // reseller listing (selling price set by entrepreneur)
  coupons: 'coupons',
  orders: 'orders',
  sellerOrders: 'seller_orders',
  resellerOrders: 'reseller_orders',
};

const FEE_INSIDE_DHAKA = 60;
const FEE_OUTSIDE_DHAKA = 120;
const PAYMENT_METHODS = ['Cash on Delivery', 'BuyNova Wallet'];

// ============================================================
