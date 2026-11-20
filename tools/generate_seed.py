"""
Generates sql/02_dml_seed_data.sql with realistic, Indian-style sample data.

A fixed random seed makes the output identical on every run, so query
results (and the tests that check them) never change by accident.

Usage:  python tools/generate_seed.py
"""
import random
from datetime import date, datetime, timedelta
from pathlib import Path

RNG = random.Random(2026)
TODAY = date(2026, 11, 20)          # "today" for the data set (fixed, not the real clock)
ORDER_START = date(2026, 5, 1)
ORDER_END = date(2026, 11, 19)
OUT = Path(__file__).resolve().parent.parent / "sql" / "02_dml_seed_data.sql"


def q(v):
    """SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return f"{v:.2f}" if isinstance(v, float) else str(v)
    if isinstance(v, datetime):
        return f"'{v:%Y-%m-%d %H:%M:%S}'"
    if isinstance(v, date):
        return f"'{v:%Y-%m-%d}'"
    return "'" + str(v).replace("'", "''") + "'"


def insert(table, cols, rows, chunk=50):
    out = []
    for i in range(0, len(rows), chunk):
        part = rows[i:i + chunk]
        values = ",\n".join("  (" + ", ".join(q(v) for v in r) + ")" for r in part)
        out.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n{values};")
    return "\n\n".join(out)


def money(x):
    return round(x + 1e-9, 2)


# ---------------------------------------------------------------------------
# Categories: 3-level tree (id, name, parent)
# ---------------------------------------------------------------------------
CATEGORIES = [
    (1, "Electronics", None),
    (2, "Mobiles", 1),
    (3, "Smartphones", 2),
    (4, "Mobile Accessories", 2),
    (5, "Audio", 1),
    (6, "Earbuds", 5),
    (7, "Headphones", 5),
    (8, "Computers", 1),
    (9, "Laptops", 8),
    (10, "Computer Accessories", 8),
    (11, "Fashion", None),
    (12, "Men", 11),
    (13, "Men's T-Shirts", 12),
    (14, "Women", 11),
    (15, "Women's Kurtas", 14),
    (16, "Footwear", 11),
    (17, "Sports Shoes", 16),
    (18, "Home & Kitchen", None),
    (19, "Kitchen Appliances", 18),
    (20, "Home Decor", 18),
    (21, "Books", None),
    (22, "Fiction", 21),
    (23, "Non-Fiction", 21),
]

# (sku, name, category_id, brand, price, mrp, popularity weight)
PRODUCTS = [
    ("SAM-S24",     "Samsung Galaxy S24 (8GB/256GB)",   3, "Samsung",   74999, 79999, 4),
    ("APL-IP15",    "Apple iPhone 15 (128GB)",          3, "Apple",     69999, 79900, 5),
    ("ONP-12R",     "OnePlus 12R (8GB/128GB)",          3, "OnePlus",   39999, 42999, 5),
    ("RDM-N13P",    "Redmi Note 13 Pro 5G",             3, "Xiaomi",    23999, 26999, 7),
    ("BOAT-PB20K",  "boAt 20000mAh Power Bank",         4, "boAt",       1499,  2999, 9),
    ("SPG-CASE",    "Spigen Rugged Armor Phone Case",   4, "Spigen",      899,  1499, 14),
    ("SAM-CHG25",   "Samsung 25W Type-C Charger",       4, "Samsung",    1299,  1999, 10),
    ("PTR-CBL",     "Portronics Konnect USB-C Cable",   4, "Portronics",  299,   599, 22),
    ("BOAT-AD141",  "boAt Airdopes 141",                6, "boAt",       1299,  4490, 30),
    ("ONP-NB2",     "OnePlus Nord Buds 2",              6, "OnePlus",    2299,  2999, 12),
    ("APL-APP2",    "Apple AirPods Pro (2nd Gen)",      6, "Apple",     24900, 26900, 3),
    ("SNY-XM5",     "Sony WH-1000XM5 Headphones",       7, "Sony",      29990, 34990, 3),
    ("JBL-760NC",   "JBL Tune 760NC Headphones",        7, "JBL",        5999,  7999, 6),
    ("BOAT-RK450",  "boAt Rockerz 450 Headphones",      7, "boAt",       1499,  3990, 11),
    ("HP-PAV15",    "HP Pavilion 15 Laptop (i5)",       9, "HP",        62990, 72990, 2),
    ("LEN-IPS3",    "Lenovo IdeaPad Slim 3 (Ryzen 5)",  9, "Lenovo",    45990, 57990, 3),
    ("APL-MBA-M3",  "Apple MacBook Air M3 13-inch",     9, "Apple",    114900, 114900, 0),
    ("ASU-VB15",    "ASUS Vivobook 15 (i3)",            9, "ASUS",      38990, 49990, 2),
    ("LOG-MX3S",    "Logitech MX Master 3S Mouse",     10, "Logitech",   8995, 10995, 4),
    ("SND-128",     "SanDisk Ultra 128GB Pendrive",    10, "SanDisk",     899,  1599, 13),
    ("HP-M24",      "HP M24f 24-inch FHD Monitor",     10, "HP",        10499, 14999, 4),
    ("ALS-POLO",    "Allen Solly Men's Polo T-Shirt",  13, "Allen Solly", 899,  1499, 10),
    ("USP-CREW",    "U.S. Polo Assn. Crew Neck Tee",   13, "U.S. Polo Assn.", 799, 1299, 8),
    ("RDS-GTEE",    "Roadster Graphic Print T-Shirt",  13, "Roadster",    449,   999, 16),
    ("BIBA-KRT",    "Biba Cotton Straight Kurta",      15, "Biba",       1299,  2199, 9),
    ("W-PKRT",      "W Printed A-Line Kurta",          15, "W",          1099,  1799, 7),
    ("LBS-ANK",     "Libas Anarkali Kurta Set",        15, "Libas",      1599,  2999, 5),
    ("NKE-REV6",    "Nike Revolution 6 Running Shoes", 17, "Nike",       3695,  3695, 6),
    ("PMA-SOFT",    "Puma Softride Running Shoes",     17, "Puma",       2999,  5999, 7),
    ("CMP-RUN",     "Campus North Plus Running Shoes", 17, "Campus",     1299,  1999, 9),
    ("PRS-IND",     "Prestige PIC 20 Induction Cooktop", 19, "Prestige", 2299,  3495, 6),
    ("PHL-MXR",     "Philips HL7756 Mixer Grinder",    19, "Philips",    3499,  4995, 5),
    ("PGN-KTL",     "Pigeon 1.5L Electric Kettle",     19, "Pigeon",      699,  1295, 11),
    ("BJJ-OTG",     "Bajaj 1603T 16L OTG",             19, "Bajaj",      5499,  6999, 3),
    ("AJT-CLK",     "Ajanta Quartz Wall Clock",        20, "Ajanta",      799,  1499, 0),
    ("HS-CUSH",     "Home Sizzler Cushion Covers (Set of 5)", 20, "Home Sizzler", 499, 999, 6),
    ("BK-PALACE",   "The Palace of Illusions",         22, "HarperCollins", 349,  499, 8),
    ("BK-ATOMIC",   "Atomic Habits",                   23, "Penguin",     399,   799, 25),
    ("BK-WINGS",    "Wings of Fire",                   23, "Universities Press", 249, 399, 12),
    ("BK-IKIGAI",   "Ikigai",                          23, "Penguin",     299,   599, 15),
]
# Price history: before the cut-off date these products sold at a different price.
PRICE_HISTORY = {
    "APL-IP15": (date(2026, 9, 10), 72999),   # price cut after new model launch
    "RDM-N13P": (date(2026, 8, 1), 25999),
    "ONP-NB2":  (date(2026, 7, 15), 2499),
    "BK-ATOMIC": (date(2026, 7, 1), 449),
    "PMA-SOFT": (date(2026, 10, 1), 2799),    # price went UP after festive season
}

WAREHOUSES = [
    (1, "Bhiwandi FC", "Mumbai", "Maharashtra"),
    (2, "Gurugram FC", "Gurugram", "Haryana"),
    (3, "Bengaluru FC", "Bengaluru", "Karnataka"),
]

# city -> (state, pincode prefix, region warehouse)
CITIES = {
    "Mumbai": ("Maharashtra", "4000", 1), "Pune": ("Maharashtra", "4110", 1),
    "Ahmedabad": ("Gujarat", "3800", 1), "Indore": ("Madhya Pradesh", "4520", 1),
    "Delhi": ("Delhi", "1100", 2), "Jaipur": ("Rajasthan", "3020", 2),
    "Lucknow": ("Uttar Pradesh", "2260", 2), "Chandigarh": ("Chandigarh", "1600", 2),
    "Kolkata": ("West Bengal", "7000", 2), "Patna": ("Bihar", "8000", 2),
    "Bengaluru": ("Karnataka", "5600", 3), "Hyderabad": ("Telangana", "5000", 3),
    "Chennai": ("Tamil Nadu", "6000", 3), "Kochi": ("Kerala", "6820", 3),
}
STREETS = ["MG Road", "Station Road", "Park Street", "Nehru Nagar", "Gandhi Chowk",
           "Civil Lines", "Lake View Road", "Sector 21", "Shivaji Nagar", "Anna Salai",
           "Banjara Hills Rd 3", "Salt Lake Sector V", "Vaishali Nagar", "Hazratganj",
           "Koramangala 5th Block", "Andheri East", "Viman Nagar", "Navrangpura"]

NAMES = [
    ("Aarav Sharma", "M"), ("Priya Nair", "F"), ("Rohan Mehta", "M"), ("Ananya Iyer", "F"),
    ("Vikram Singh", "M"), ("Sneha Patil", "F"), ("Arjun Reddy", "M"), ("Kavya Menon", "F"),
    ("Aditya Verma", "M"), ("Isha Gupta", "F"), ("Karan Malhotra", "M"), ("Pooja Desai", "F"),
    ("Rahul Joshi", "M"), ("Neha Kulkarni", "F"), ("Siddharth Rao", "M"), ("Meera Pillai", "F"),
    ("Aman Choudhary", "M"), ("Riya Banerjee", "F"), ("Nikhil Jain", "M"), ("Divya Krishnan", "F"),
    ("Harsh Agarwal", "M"), ("Tanvi Shah", "F"), ("Manish Yadav", "M"), ("Shreya Das", "F"),
    ("Varun Kapoor", "M"), ("Nisha Thakur", "F"), ("Yash Saxena", "M"), ("Aditi Bhatt", "F"),
    ("Kunal Bose", "M"), ("Simran Kaur", "F"), ("Abhishek Mishra", "M"), ("Lakshmi Subramanian", "F"),
    ("Deepak Pandey", "M"), ("Anjali Tiwari", "F"), ("Gaurav Sinha", "M"), ("Ritika Arora", "F"),
    ("Mohit Bansal", "M"), ("Swati Chavan", "F"), ("Pranav Hegde", "M"), ("Sakshi Mittal", "F"),
    ("Tushar Naidu", "M"), ("Payal Ghosh", "F"), ("Saurabh Dubey", "M"), ("Kritika Sood", "F"),
    ("Alok Tripathi", "M"), ("Bhavna Rathore", "F"), ("Imran Qureshi", "M"), ("Fatima Sheikh", "F"),
    ("Jaspreet Gill", "M"), ("Sam Fernandes", "O"),
]
COURIERS = ["Delhivery", "Blue Dart", "Ekart", "XpressBees", "Shadowfax"]

DISCOUNTS = [
    # id, code, description, type, value, min_order, from, to
    (1, "WELCOME100", "Rs 100 off on your first order", "FLAT", 100, 499, date(2025, 1, 1), date(2026, 12, 31)),
    (2, "SAVE10", "10% off on orders above Rs 1000", "PERCENT", 10, 1000, date(2026, 5, 1), date(2026, 12, 31)),
    (3, "MONSOON15", "Monsoon sale: 15% off above Rs 2000", "PERCENT", 15, 2000, date(2026, 6, 15), date(2026, 8, 31)),
    (4, "FESTIVE20", "Diwali festive sale: 20% off above Rs 3000", "PERCENT", 20, 3000, date(2026, 10, 10), date(2026, 11, 5)),
    (5, "FLAT500", "Rs 500 off on orders above Rs 5000", "FLAT", 500, 5000, date(2026, 5, 1), date(2026, 11, 30)),
    (6, "SUMMER25", "Summer sale (expired, never used)", "PERCENT", 25, 1500, date(2026, 4, 1), date(2026, 4, 30)),
]


def rand_date(a, b):
    return a + timedelta(days=RNG.randint(0, (b - a).days))


def build():
    # ---------------- customers (IDs in signup order) ----------------
    signups = sorted(rand_date(date(2025, 1, 5), date(2026, 9, 30)) for _ in NAMES)
    names = NAMES[:]
    RNG.shuffle(names)
    customers, addresses = [], []
    city_list = list(CITIES)
    phones = set()
    cust_city = {}
    for cid, ((name, g), signup) in enumerate(zip(names, signups), start=1):
        first, last = name.lower().split(" ", 1)
        email = f"{first}.{last.replace(' ', '')}{cid}@example.in"
        while True:
            phone = str(RNG.choice([6, 7, 8, 9])) + "".join(str(RNG.randint(0, 9)) for _ in range(9))
            if phone not in phones:
                phones.add(phone)
                break
        dob = None if cid % 9 == 0 else rand_date(date(1975, 1, 1), date(2005, 12, 31))
        referred = None
        if cid > 5 and RNG.random() < 0.32:
            referred = RNG.randint(1, cid - 1)
        customers.append([cid, name, email, phone, g, dob, signup, referred])
        city = RNG.choice(city_list)
        cust_city[cid] = city
        state, pin, _ = CITIES[city]
        addresses.append([None, cid, "HOME", f"{RNG.randint(1, 250)}, {RNG.choice(STREETS)}",
                          city, state, pin + f"{RNG.randint(1, 99):02d}", True])
        if RNG.random() < 0.25:
            addresses.append([None, cid, "WORK", f"Office {RNG.randint(101, 999)}, {RNG.choice(STREETS)}",
                              city, state, pin + f"{RNG.randint(1, 99):02d}", False])
    for aid, a in enumerate(addresses, start=1):
        a[0] = aid
    addr_by_cust = {}
    for a in addresses:
        addr_by_cust.setdefault(a[1], []).append(a[0])

    # ---------------- order counts per customer ----------------
    ids = [c[0] for c in customers]
    late_signups = [c[0] for c in customers if c[6] > date(2026, 8, 1)]
    zero = set(sorted(late_signups, reverse=True)[:3] + RNG.sample([i for i in ids if i not in late_signups], 3))
    rest = [i for i in ids if i not in zero]
    heavy = set(RNG.sample(rest, 8))
    rest2 = [i for i in rest if i not in heavy]
    single = set(RNG.sample(rest2, 10))
    counts = {}
    for cid in ids:
        if cid in zero:
            counts[cid] = 0
        elif cid in heavy:
            counts[cid] = RNG.randint(12, 17)
        elif cid in single:
            counts[cid] = 1
        else:
            counts[cid] = RNG.randint(3, 9)

    # ---------------- raw orders ----------------
    signup_of = {c[0]: c[6] for c in customers}
    raw = []
    for cid in ids:
        start = max(signup_of[cid], ORDER_START)
        for _ in range(counts[cid]):
            d = rand_date(start, ORDER_END)
            ts = datetime(d.year, d.month, d.day, RNG.randint(8, 23), RNG.randint(0, 59), RNG.randint(0, 59))
            raw.append((ts, cid))
    raw.sort()

    prod_ids = list(range(1, len(PRODUCTS) + 1))
    weights = [p[6] for p in PRODUCTS]
    disc_by_id = {d[0]: d for d in DISCOUNTS}

    orders, items, payments, order_discounts, deliveries = [], [], [], [], []
    first_order_seen = set()
    pay_id = 0
    pending_prepaid = 0
    for oid, (ts, cid) in enumerate(raw, start=1001):
        # items
        n_items = RNG.choices([1, 2, 3, 4], [45, 32, 16, 7])[0]
        chosen = set()
        while len(chosen) < n_items:
            chosen.add(RNG.choices(prod_ids, weights)[0])
        subtotal = 0.0
        for pid in sorted(chosen):
            sku, _, _, _, price, _, _ = PRODUCTS[pid - 1]
            unit = price
            if sku in PRICE_HISTORY and ts.date() < PRICE_HISTORY[sku][0]:
                unit = PRICE_HISTORY[sku][1]
            qty = RNG.choices([1, 2, 3], [75, 18, 7])[0] if price < 2000 else 1
            items.append([oid, pid, qty, float(unit)])
            subtotal += qty * unit
        subtotal = money(subtotal)

        # coupon
        saved = 0.0
        if RNG.random() < 0.30:
            eligible = []
            for d in DISCOUNTS:
                did, code, _, typ, val, mn, vf, vt = d
                if not (vf <= ts.date() <= vt) or subtotal < mn:
                    continue
                if code == "WELCOME100" and cid in first_order_seen:
                    continue
                eligible.append(d)
            if eligible:
                d = RNG.choice(eligible)
                saved = float(d[4]) if d[3] == "FLAT" else money(subtotal * d[4] / 100)
                order_discounts.append([oid, d[0], saved])
        first_order_seen.add(cid)
        total = money(subtotal - saved)

        # payment scenario
        age = (TODAY - ts.date()).days
        r = RNG.random()
        if age <= 12 and RNG.random() < 0.25:
            scenario = "pending"          # recent prepaid order, bank has not confirmed yet
        elif r < 0.05:
            scenario = "failed_only"      # every attempt failed -> order cancelled
        elif r < 0.13:
            scenario = "retry"            # one failed attempt, then success
        else:
            scenario = "success"
        method = RNG.choices(["UPI", "CARD", "COD", "NET_BANKING"], [45, 25, 15, 15])[0]
        if scenario in ("failed_only", "retry", "pending") and method == "COD":
            method = "UPI"
        if scenario == "pending" and pending_prepaid % 2 == 1:
            method = "NET_BANKING"

        def add_payment(m, status, when):
            nonlocal pay_id
            pay_id += 1
            ref = None if m == "COD" else {"UPI": "UPI", "CARD": "CRD", "NET_BANKING": "NB"}[m] + f"{ts:%y%m%d}{pay_id:06d}"
            payments.append([pay_id, oid, m, status, total, when, ref])

        # delivery / order status
        wh = CITIES[cust_city[cid]][2]
        ship_addr = RNG.choice(addr_by_cust[cid]) if RNG.random() < 0.2 else addr_by_cust[cid][0]
        status = None
        delivery = None
        if scenario == "failed_only":
            add_payment(method, "FAILED", ts + timedelta(minutes=1))
            if RNG.random() < 0.4:
                add_payment(method, "FAILED", ts + timedelta(minutes=4))
            status = "CANCELLED"
        elif scenario == "pending":
            add_payment(method, "PENDING", ts + timedelta(minutes=1))
            pending_prepaid += 1
            status = "PLACED"
        else:
            if scenario == "retry":
                first = RNG.choice(["UPI", "CARD"])
                second = ("CARD" if first == "UPI" else "UPI") if RNG.random() < 0.75 else "NET_BANKING"
                add_payment(first, "FAILED", ts + timedelta(minutes=1))
                method = second
            # delivery timeline
            ship = ts.date() + timedelta(days=RNG.randint(1, 2))
            arrive = ship + timedelta(days=RNG.randint(2, 6))
            if age <= 3:
                dstat = RNG.choice(["PENDING", "PENDING", "SHIPPED"])
            elif age <= 10:
                dstat = "DELIVERED" if arrive <= TODAY and RNG.random() < 0.4 else RNG.choice(["SHIPPED", "IN_TRANSIT"])
            else:
                dstat = "RETURNED" if (method != "COD" and RNG.random() < 0.04) else "DELIVERED"
            shipped = None if dstat == "PENDING" else ship
            delivered = arrive if dstat in ("DELIVERED", "RETURNED") else None
            tracking = None if dstat == "PENDING" else f"{RNG.choice(['DLV', 'BD', 'EK', 'XB', 'SF'])}{oid}{RNG.randint(100, 999)}"
            delivery = [None, oid, wh, RNG.choice(COURIERS), tracking, dstat, shipped, delivered]
            status = {"PENDING": "CONFIRMED", "SHIPPED": "SHIPPED", "IN_TRANSIT": "SHIPPED",
                      "DELIVERED": "DELIVERED", "RETURNED": "CANCELLED"}[dstat]
            if method == "COD":
                if delivered and dstat == "DELIVERED":
                    add_payment("COD", "SUCCESS", datetime(delivered.year, delivered.month, delivered.day, 18, 30))
                else:
                    add_payment("COD", "PENDING", ts + timedelta(minutes=1))
            else:
                add_payment(method, "SUCCESS", ts + timedelta(minutes=5))
        orders.append([oid, cid, ship_addr, ts, status])
        if delivery:
            deliveries.append(delivery)
    for i, d in enumerate(deliveries, start=1):
        d[0] = i

    # ---------------- inventory ----------------
    inventory = []
    for pid, p in enumerate(PRODUCTS, start=1):
        whs = sorted(RNG.sample([1, 2, 3], RNG.choice([2, 3])))
        for w in whs:
            reorder = 10 if p[4] > 5000 else 20
            qty = RNG.randint(15, 180)
            if p[0] == "SNY-XM5":
                qty = 0                      # sold out everywhere
            elif RNG.random() < 0.12:
                qty = RNG.randint(0, reorder - 1)   # low stock
            inventory.append([pid, w, qty, reorder])

    return customers, addresses, orders, items, payments, order_discounts, deliveries, inventory


def main():
    (customers, addresses, orders, items, payments, order_discounts,
     deliveries, inventory) = build()

    parts = [
        "-- =====================================================================",
        "-- 02_dml_seed_data.sql",
        "-- Syllabus: SQL Fundamentals (DML: INSERT)",
        "-- Realistic sample data for the e-commerce schema.",
        "-- Generated by tools/generate_seed.py (fixed random seed, so it is",
        "-- reproducible). Do not edit by hand: change the script and re-run it.",
        f"-- Rows: {len(customers)} customers, {len(addresses)} addresses, {len(CATEGORIES)} categories,",
        f"--       {len(PRODUCTS)} products, {len(WAREHOUSES)} warehouses, {len(inventory)} inventory rows,",
        f"--       {len(orders)} orders, {len(items)} order items, {len(payments)} payments,",
        f"--       {len(DISCOUNTS)} coupons, {len(order_discounts)} coupon uses, {len(deliveries)} deliveries.",
        "-- =====================================================================",
        "",
        "-- Customers are inserted in signup order. referred_by always points to an",
        "-- earlier customer. Names, emails and phone numbers are fictional.",
        insert("customers", ["customer_id", "full_name", "email", "phone", "gender",
                             "date_of_birth", "signup_date", "referred_by"], customers),
        "",
        insert("customer_addresses", ["address_id", "customer_id", "address_type", "line1",
                                      "city", "state", "pincode", "is_default"], addresses),
        "",
        "-- Category tree: parents are inserted before their children.",
        insert("categories", ["category_id", "category_name", "parent_category_id"], CATEGORIES),
        "",
        insert("products", ["product_id", "sku", "product_name", "category_id", "brand", "price", "mrp"],
               [[i, p[0], p[1], p[2], p[3], float(p[4]), float(p[5])] for i, p in enumerate(PRODUCTS, start=1)]),
        "",
        insert("warehouses", ["warehouse_id", "warehouse_name", "city", "state"], WAREHOUSES),
        "",
        insert("inventory", ["product_id", "warehouse_id", "quantity", "reorder_level"], inventory),
        "",
        insert("discounts", ["discount_id", "code", "description", "discount_type", "discount_value",
                             "min_order_value", "valid_from", "valid_to"],
               [[d[0], d[1], d[2], d[3], float(d[4]), float(d[5]), d[6], d[7]] for d in DISCOUNTS]),
        "",
        "-- Orders: IDs follow order_date. Status matches the delivery and payment state.",
        insert("orders", ["order_id", "customer_id", "shipping_address_id", "order_date", "status"], orders),
        "",
        "-- unit_price = price at the time of purchase (some differ from today's price).",
        insert("order_items", ["order_id", "product_id", "quantity", "unit_price"], items),
        "",
        insert("order_discounts", ["order_id", "discount_id", "amount_saved"], order_discounts),
        "",
        "-- Payments: an order may have a FAILED attempt before the SUCCESS one.",
        "-- Successful amount = items total - coupon saving.",
        insert("payments", ["payment_id", "order_id", "method", "status", "amount", "paid_at",
                            "transaction_ref"], payments),
        "",
        insert("deliveries", ["delivery_id", "order_id", "warehouse_id", "courier", "tracking_no",
                              "status", "shipped_date", "delivered_date"], deliveries),
        "",
    ]
    OUT.write_text("\n".join(parts), encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(orders)} orders, {len(items)} items, {len(payments)} payments)")


if __name__ == "__main__":
    main()
