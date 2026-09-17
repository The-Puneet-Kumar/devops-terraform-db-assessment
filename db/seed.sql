-- Deterministic seed set: 120 bookings, 4 organizations, 6 cities, 4 statuses.
INSERT INTO hotel_bookings (
    id, org_id, hotel_id, city, checkin_date, checkout_date,
    amount, status, created_at
)
SELECT
    gen_random_uuid(),
    ('00000000-0000-0000-0000-' || lpad(((g - 1) % 4 + 1)::text, 12, '0'))::uuid,
    'HOTEL-' || lpad(((g - 1) % 20 + 1)::text, 3, '0'),
    (ARRAY['delhi', 'mumbai', 'bangalore', 'pune', 'jaipur', 'hyderabad'])[((g - 1) % 6) + 1],
    CURRENT_DATE + ((g % 20) || ' days')::interval,
    CURRENT_DATE + ((g % 20 + 2) || ' days')::interval,
    (1200 + (g * 137 % 8500))::numeric(12,2),
    (ARRAY['confirmed', 'pending', 'cancelled', 'completed'])[((g - 1) % 4) + 1],
    NOW() - ((g % 45) || ' days')::interval
FROM generate_series(1, 120) AS g;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    hb.id,
    (ARRAY['booking_created', 'payment_received', 'booking_confirmed'])[((row_number() OVER ())::int - 1) % 3 + 1],
    jsonb_build_object(
        'source', 'seed',
        'booking_id', hb.id::text,
        'message', 'assessment test event'
    ),
    hb.created_at + interval '10 minutes'
FROM (
    SELECT id, created_at
    FROM hotel_bookings
    ORDER BY created_at
    LIMIT 80
) AS hb;
