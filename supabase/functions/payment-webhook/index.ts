import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

async function hmacHex(secret: string, body: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  const raw = await req.text();
  const signature = req.headers.get('x-razorpay-signature') ?? '';
  const expected = await hmacHex(Deno.env.get('RAZORPAY_WEBHOOK_SECRET')!, raw);
  if (signature !== expected) return new Response('bad signature', { status: 401 });

  const event = JSON.parse(raw);
  if (event.event === 'payment.captured' || event.event === 'order.paid') {
    const p = event.payload.payment.entity;
    const bookingId = p.notes?.booking_id;
    if (bookingId) {
      const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
      const { error } = await admin.rpc('confirm_booking_payment', {
        p_booking: bookingId, p_provider_payment_id: p.id, p_amount: p.amount / 100,
      });
      if (error) return new Response(error.message, { status: 500 });
    }
  }
  return new Response('ok');
});
