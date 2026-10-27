import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authHeader = req.headers.get('Authorization')!;
    const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } });
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { booking_id } = await req.json();

    const { data: booking, error } = await userClient.from('bookings')
      .select('id, total_amount, status, driver_id').eq('id', booking_id).single();
    if (error || !booking || booking.status !== 'pending_payment') throw new Error('invalid_booking');

    const amountPaise = Math.round(Number(booking.total_amount) * 100);
    const rz = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Basic ' + btoa(`${Deno.env.get('RAZORPAY_KEY_ID')}:${Deno.env.get('RAZORPAY_KEY_SECRET')}`),
      },
      body: JSON.stringify({ amount: amountPaise, currency: 'INR', receipt: booking.id, notes: { booking_id: booking.id } }),
    });
    const order = await rz.json();
    if (!rz.ok) throw new Error(order?.error?.description ?? 'razorpay_error');

    await admin.from('payments').insert({
      booking_id: booking.id, provider: 'razorpay', provider_order_id: order.id,
      amount: booking.total_amount, currency: 'INR',
    });

    return new Response(JSON.stringify({
      order_id: order.id, amount: amountPaise, currency: 'INR', key_id: Deno.env.get('RAZORPAY_KEY_ID'),
    }), { headers: { ...cors, 'Content-Type': 'application/json' } });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: String(e.message ?? e) }), { status: 400, headers: cors });
  }
});
