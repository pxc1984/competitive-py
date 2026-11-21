"""Генератор данных для БД лотерейного оператора: пишет CSV в каталог data рядом со скриптом."""

import csv
import random
from bisect import bisect_right
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta, timezone
from decimal import ROUND_HALF_UP, Decimal
from itertools import accumulate
from pathlib import Path

RANDOM_SEED = 20261115
MOSCOW = timezone(timedelta(hours=3), "MSK")
HISTORY_START = datetime(2024, 11, 1, tzinfo=MOSCOW)
NOW = datetime(2026, 11, 15, 12, 0, tzinfo=MOSCOW)
SALES_HORIZON = timedelta(days=7)
# Полночь, а не 23:59:59: при переводе в восточные часовые пояса дата не должна уйти в 10000 год
OPEN_END_DTTM = datetime(9999, 12, 31, tzinfo=UTC)
DATA_DIR = Path(__file__).resolve().parent / "data"

USERS_COUNT = 4000
NEVER_PLAYED_SHARE = 0.12
CANCELLED_DRAWS_COUNT = 3
RANDOM_REFUND_SHARE = 0.004
PROMO_HALF_PRICE_SHARE = 0.02
PROMO_FREE_TICKET_SHARE = 0.003
USER_PICK_ATTEMPTS = 30
SALES_WINDOW = timedelta(days=14)
SALES_CLOSE_BEFORE_DRAW = timedelta(minutes=5)

AUTO_CREDIT_LIMIT = Decimal(10_000)
CLAIM_EXPIRY = timedelta(days=180)
UNCLAIMED_SHARE = 0.12
CENT = Decimal("0.01")

CHANNEL_WEIGHTS = {"mobile": 0.55, "web": 0.35, "retail": 0.10}
USER_STATUS_WEIGHTS = {"active": 0.93, "blocked": 0.05, "deleted": 0.02}
# Одни и те же города записаны по-разному: так данные приходят из анкет без справочника
CITY_WEIGHTS = {
    "Москва": 30,
    "москва": 3,
    "г. Москва": 4,
    "Мск": 1,
    "Санкт-Петербург": 14,
    "СПб": 3,
    "Питер": 1,
    "Новосибирск": 6,
    "Екатеринбург": 6,
    "Казань": 5,
    "Нижний Новгород": 4,
    "Самара": 3,
    "Ростов-на-Дону": 4,
    "Краснодар": 4,
    "Уфа": 2,
    "Пермь": 2,
    "Воронеж": 2,
    "Владивосток": 1,
    "Калининград": 1,
    None: 2,  # город в анкете не указан
}
EMAIL_DOMAINS = ("mail.ru", "yandex.ru", "gmail.com", "bk.ru", "inbox.ru", "rambler.ru")

MALE_FIRST_NAMES = (
    "Александр",
    "Дмитрий",
    "Максим",
    "Сергей",
    "Андрей",
    "Алексей",
    "Иван",
    "Михаил",
    "Никита",
    "Егор",
    "Павел",
    "Роман",
    "Олег",
    "Виктор",
    "Николай",
    "Юрий",
)
FEMALE_FIRST_NAMES = (
    "Анна",
    "Мария",
    "Елена",
    "Ольга",
    "Наталья",
    "Татьяна",
    "Ирина",
    "Екатерина",
    "Светлана",
    "Юлия",
    "Дарья",
    "Полина",
    "Алина",
    "Ксения",
    "Вера",
    "Людмила",
)
MALE_LAST_NAMES = (
    "Иванов",
    "Смирнов",
    "Кузнецов",
    "Попов",
    "Васильев",
    "Петров",
    "Соколов",
    "Михайлов",
    "Новиков",
    "Федоров",
    "Морозов",
    "Волков",
    "Алексеев",
    "Лебедев",
    "Семенов",
    "Егоров",
    "Павлов",
    "Козлов",
    "Степанов",
    "Николаев",
    "Орлов",
    "Андреев",
    "Макаров",
    "Никитин",
)
TRANSLITERATION = dict(
    zip(
        "абвгдеёжзийклмнопрстуфхцчшщъыьэюя",
        (
            "a",
            "b",
            "v",
            "g",
            "d",
            "e",
            "e",
            "zh",
            "z",
            "i",
            "y",
            "k",
            "l",
            "m",
            "n",
            "o",
            "p",
            "r",
            "s",
            "t",
            "u",
            "f",
            "kh",
            "ts",
            "ch",
            "sh",
            "sch",
            "",
            "y",
            "",
            "e",
            "yu",
            "ya",
        ),
        strict=True,
    )
)


@dataclass(frozen=True)
class TermsVersion:
    starts_at: datetime
    ticket_price: Decimal
    jackpot_share: Decimal


@dataclass(frozen=True)
class LotteryFormat:
    code: str
    name: str
    numbers_total: int
    numbers_picked: int
    first_draw_at: datetime
    draw_interval: timedelta
    closed_at: datetime | None
    mean_tickets_per_draw: int
    terms_history: tuple[TermsVersion, ...]
    prize_multipliers: dict[int, int]
    jackpot_seed: Decimal


def moscow(year: int, month: int, day: int, hour: int = 0) -> datetime:
    return datetime(year, month, day, hour, tzinfo=MOSCOW)


def terms(
    year: int, month: int, day: int, price: int, jackpot_share: str
) -> TermsVersion:
    return TermsVersion(
        moscow(year, month, day), Decimal(price), Decimal(jackpot_share)
    )


# Множители призов задаются от базовой цены билета; полное совпадение забирает накопленный джекпот
LOTTERY_FORMATS = (
    LotteryFormat(
        "QUICK420",
        "Быстрые 4 из 20",
        20,
        4,
        moscow(2024, 11, 1, 21),
        timedelta(days=2),
        None,
        26,
        (
            terms(2024, 11, 1, 50, "0.20"),
            terms(2025, 4, 1, 60, "0.20"),
            terms(2026, 2, 1, 80, "0.18"),
        ),
        {2: 1, 3: 20},
        Decimal(50_000),
    ),
    LotteryFormat(
        "SPORT536",
        "Спортлото 5 из 36",
        36,
        5,
        moscow(2024, 11, 2, 20),
        timedelta(days=3),
        None,
        60,
        (terms(2024, 11, 1, 80, "0.20"), terms(2025, 9, 15, 100, "0.22")),
        {2: 1, 3: 15, 4: 300},
        Decimal(300_000),
    ),
    LotteryFormat(
        "GOS645",
        "Гослото 6 из 45",
        45,
        6,
        moscow(2024, 11, 3, 22),
        timedelta(days=7),
        None,
        120,
        (
            terms(2024, 11, 1, 100, "0.25"),
            terms(2025, 6, 1, 150, "0.25"),
            terms(2026, 6, 1, 150, "0.30"),
        ),
        {3: 10, 4: 60, 5: 1500},
        Decimal(10_000_000),
    ),
    LotteryFormat(
        "MEGA749",
        "Мега 7 из 49",
        49,
        7,
        moscow(2024, 11, 5, 22),
        timedelta(days=7),
        None,
        90,
        (terms(2024, 11, 1, 150, "0.30"),),
        {3: 3, 4: 40, 5: 500, 6: 10000},
        Decimal(50_000_000),
    ),
    LotteryFormat(
        "NIGHT420",
        "Ночной экспресс 4 из 20",
        20,
        4,
        moscow(2025, 6, 1, 23),
        timedelta(days=1),
        None,
        20,
        (terms(2025, 6, 1, 40, "0.15"),),
        {2: 1, 3: 25},
        Decimal(20_000),
    ),
    LotteryFormat(
        "NY645",
        "Новогодняя 6 из 45",
        45,
        6,
        moscow(2024, 12, 31, 23),
        timedelta(days=365),
        moscow(2026, 1, 15),
        900,
        (terms(2024, 11, 1, 200, "0.40"), terms(2025, 11, 1, 300, "0.40")),
        {3: 8, 4: 50, 5: 1000},
        Decimal(100_000_000),
    ),
)


@dataclass
class User:
    user_id: int
    email: str
    full_name: str
    phone: str | None
    birth_date: date | None
    city: str | None
    registered_at: datetime
    status: str
    activity_weight: float


@dataclass(frozen=True)
class Lottery:
    lottery_id: int
    lottery_format: LotteryFormat
    terms_ids: tuple[int, ...]

    def terms_at(self, moment: datetime) -> TermsVersion:
        starts = [version.starts_at for version in self.lottery_format.terms_history]
        return self.lottery_format.terms_history[bisect_right(starts, moment) - 1]


@dataclass
class Draw:
    draw_id: int
    lottery: Lottery
    draw_number: int
    scheduled_at: datetime
    drawn_at: datetime | None
    status: str
    winning_numbers: frozenset[int]


@dataclass
class Ticket:
    ticket_id: int
    user_id: int
    draw: Draw
    purchased_at: datetime
    price_paid: Decimal
    channel: str
    status: str
    numbers: frozenset[int]


@dataclass(frozen=True)
class Prize:
    prize_id: int
    ticket_id: int
    matched_count: int
    amount: Decimal
    status: str
    paid_at: datetime | None


@dataclass(frozen=True)
class WeightedPicker[T]:
    items: Sequence[T]
    cumulative_weights: Sequence[float]

    @classmethod
    def of(cls, weights: Mapping[T, float]) -> WeightedPicker[T]:
        return cls(tuple(weights), tuple(accumulate(weights.values())))

    def pick(self, rng: random.Random) -> T:
        return rng.choices(self.items, cum_weights=self.cumulative_weights)[0]


def random_moment(rng: random.Random, start: datetime, end: datetime) -> datetime:
    seconds = (end - start).total_seconds()
    return start + timedelta(seconds=rng.uniform(0, seconds))


def transliterate(text: str) -> str:
    return "".join(TRANSLITERATION.get(letter, letter) for letter in text.lower())


def random_phone(rng: random.Random) -> str | None:
    if rng.random() < 0.08:
        return None
    code, first, second, third = (
        rng.randint(900, 999),
        rng.randint(100, 999),
        rng.randint(10, 99),
        rng.randint(10, 99),
    )
    formats = (
        f"+7 ({code}) {first}-{second}-{third}",
        f"8{code}{first}{second}{third}",
        f"+7{code}{first}{second}{third}",
        f"8 {code} {first} {second} {third}",
    )
    return rng.choice(formats)


def random_birth_date(rng: random.Random) -> date | None:
    roll = rng.random()
    if roll < 0.04:
        return None
    # Заглушка из старой анкеты, где дата рождения была обязательной
    if roll < 0.045:
        return date(1900, 1, 1)
    age_days = rng.randint(18 * 365, 80 * 365)
    return NOW.date() - timedelta(days=age_days)


def random_email(
    rng: random.Random, user_id: int, first_name: str, last_name: str
) -> str:
    local_part = rng.choice(
        (
            f"{transliterate(last_name)}.{transliterate(first_name)}{user_id}",
            f"{transliterate(first_name)[0]}{transliterate(last_name)}{user_id}",
            f"{transliterate(last_name)}_{rng.randint(1960, 2007)}_{user_id}",
        )
    )
    email = f"{local_part}@{rng.choice(EMAIL_DOMAINS)}"
    return email.upper() if rng.random() < 0.03 else email


def random_activity_weight(rng: random.Random) -> float:
    if rng.random() < NEVER_PLAYED_SHARE:
        return 0.0
    # Хвост Парето даёт несколько игроков, покупающих сотни билетов
    return min(rng.paretovariate(1.3), 200.0)


def generate_users(rng: random.Random) -> list[User]:
    city_picker = WeightedPicker.of(CITY_WEIGHTS)
    status_picker = WeightedPicker.of(USER_STATUS_WEIGHTS)
    first_registration = HISTORY_START - timedelta(days=365)
    users = []
    for user_id in range(1, USERS_COUNT + 1):
        is_female = rng.random() < 0.45
        first_name = rng.choice(FEMALE_FIRST_NAMES if is_female else MALE_FIRST_NAMES)
        last_name = rng.choice(MALE_LAST_NAMES) + ("а" if is_female else "")
        registered_at = random_moment(rng, first_registration, NOW - timedelta(days=1))
        users.append(
            User(
                user_id=user_id,
                email=random_email(rng, user_id, first_name, last_name),
                full_name=f"{last_name} {first_name}",
                phone=random_phone(rng),
                birth_date=random_birth_date(rng),
                city=city_picker.pick(rng),
                registered_at=registered_at,
                status=status_picker.pick(rng),
                activity_weight=random_activity_weight(rng),
            )
        )
    return users


def build_lotteries() -> list[Lottery]:
    lotteries = []
    next_terms_id = 1
    for lottery_id, lottery_format in enumerate(LOTTERY_FORMATS, start=1):
        versions_count = len(lottery_format.terms_history)
        terms_ids = tuple(range(next_terms_id, next_terms_id + versions_count))
        next_terms_id += versions_count
        lotteries.append(Lottery(lottery_id, lottery_format, terms_ids))
    return lotteries


def draw_schedule(lottery_format: LotteryFormat) -> Iterable[datetime]:
    last_sales_moment = NOW + SALES_HORIZON
    if lottery_format.closed_at is not None:
        last_sales_moment = min(last_sales_moment, lottery_format.closed_at)
    scheduled_at = lottery_format.first_draw_at
    while scheduled_at <= last_sales_moment:
        yield scheduled_at
        scheduled_at += lottery_format.draw_interval


def generate_draws(rng: random.Random, lotteries: Sequence[Lottery]) -> list[Draw]:
    draws = []
    for lottery in lotteries:
        lottery_format = lottery.lottery_format
        for draw_number, scheduled_at in enumerate(
            draw_schedule(lottery_format), start=1
        ):
            is_completed = scheduled_at <= NOW
            winning_numbers = (
                frozenset(
                    rng.sample(
                        range(1, lottery_format.numbers_total + 1),
                        lottery_format.numbers_picked,
                    )
                )
                if is_completed
                else frozenset()
            )
            draws.append(
                Draw(
                    draw_id=len(draws) + 1,
                    lottery=lottery,
                    draw_number=draw_number,
                    scheduled_at=scheduled_at,
                    drawn_at=scheduled_at + timedelta(seconds=rng.randint(30, 900))
                    if is_completed
                    else None,
                    status="completed" if is_completed else "scheduled",
                    winning_numbers=winning_numbers,
                )
            )
    # Сезонную лотерею не отменяем: у неё всего пара тиражей
    regular_completed_draws = [
        draw
        for draw in draws
        if draw.status == "completed" and draw.lottery.lottery_format.closed_at is None
    ]
    for draw in rng.sample(regular_completed_draws, CANCELLED_DRAWS_COUNT):
        draw.status, draw.drawn_at, draw.winning_numbers = (
            "cancelled",
            None,
            frozenset(),
        )
    return draws


def tickets_count_for(rng: random.Random, lottery_format: LotteryFormat) -> int:
    mean = lottery_format.mean_tickets_per_draw
    return max(0, round(rng.gauss(mean, mean * 0.35)))


def ticket_price(rng: random.Random, base_price: Decimal) -> Decimal:
    roll = rng.random()
    if roll < PROMO_FREE_TICKET_SHARE:
        return Decimal(0)
    if roll < PROMO_FREE_TICKET_SHARE + PROMO_HALF_PRICE_SHARE:
        return (base_price / 2).quantize(CENT, ROUND_HALF_UP)
    return base_price


def pick_buyer(
    rng: random.Random,
    users: Sequence[User],
    user_picker: WeightedPicker[int],
    purchased_at: datetime,
) -> User | None:
    for _ in range(USER_PICK_ATTEMPTS):
        user = users[user_picker.pick(rng)]
        if user.registered_at < purchased_at:
            return user
    return None


def generate_tickets(
    rng: random.Random, users: Sequence[User], draws: Sequence[Draw]
) -> list[Ticket]:
    user_picker = WeightedPicker.of(
        {index: user.activity_weight for index, user in enumerate(users)}
    )
    channel_picker = WeightedPicker.of(CHANNEL_WEIGHTS)
    tickets = []
    for draw in draws:
        lottery_format = draw.lottery.lottery_format
        sales_start = max(
            draw.scheduled_at - SALES_WINDOW,
            draw.scheduled_at - lottery_format.draw_interval,
            lottery_format.terms_history[0].starts_at,
        )
        sales_end = min(draw.scheduled_at, NOW) - SALES_CLOSE_BEFORE_DRAW
        if sales_end <= sales_start:
            continue
        for _ in range(tickets_count_for(rng, lottery_format)):
            purchased_at = random_moment(rng, sales_start, sales_end)
            buyer = pick_buyer(rng, users, user_picker, purchased_at)
            if buyer is None:
                continue
            is_refunded = (
                draw.status == "cancelled" or rng.random() < RANDOM_REFUND_SHARE
            )
            tickets.append(
                Ticket(
                    ticket_id=len(tickets) + 1,
                    user_id=buyer.user_id,
                    draw=draw,
                    purchased_at=purchased_at,
                    price_paid=ticket_price(
                        rng, draw.lottery.terms_at(purchased_at).ticket_price
                    ),
                    channel=channel_picker.pick(rng),
                    status="refunded" if is_refunded else "sold",
                    numbers=frozenset(
                        rng.sample(
                            range(1, lottery_format.numbers_total + 1),
                            lottery_format.numbers_picked,
                        )
                    ),
                )
            )
    return tickets


def prize_payment(
    rng: random.Random, ticket: Ticket, amount: Decimal
) -> tuple[str, datetime | None]:
    drawn_at = ticket.draw.drawn_at
    if drawn_at is None:
        raise ValueError(
            f"приз по билету {ticket.ticket_id} начислен до проведения тиража"
        )
    is_claim_required = ticket.channel == "retail" or amount > AUTO_CREDIT_LIMIT
    if not is_claim_required:
        return "paid", drawn_at + timedelta(minutes=rng.randint(1, 30))
    claimed_at = drawn_at + timedelta(days=rng.expovariate(1 / 20))
    if claimed_at > NOW:
        is_expired = NOW - drawn_at > CLAIM_EXPIRY
        return ("expired", None) if is_expired else ("pending", None)
    if rng.random() < UNCLAIMED_SHARE and NOW - drawn_at > CLAIM_EXPIRY:
        return "expired", None
    return "paid", claimed_at


def generate_prizes(
    rng: random.Random, draws: Sequence[Draw], tickets: Sequence[Ticket]
) -> list[Prize]:
    sold_tickets_by_draw: dict[int, list[Ticket]] = {}
    for ticket in tickets:
        if ticket.status == "sold":
            sold_tickets_by_draw.setdefault(ticket.draw.draw_id, []).append(ticket)

    prizes = []
    jackpots = {
        lottery_format.code: lottery_format.jackpot_seed
        for lottery_format in LOTTERY_FORMATS
    }
    for draw in draws:
        if draw.status != "completed":
            continue
        lottery_format = draw.lottery.lottery_format
        draw_tickets = sold_tickets_by_draw.get(draw.draw_id, [])
        draw_terms = draw.lottery.terms_at(draw.scheduled_at)
        jackpots[lottery_format.code] += (
            sum((ticket.price_paid for ticket in draw_tickets), Decimal(0))
            * draw_terms.jackpot_share
        )

        matches = [
            (ticket, len(ticket.numbers & draw.winning_numbers))
            for ticket in draw_tickets
        ]
        jackpot_winners = [
            ticket
            for ticket, matched in matches
            if matched == lottery_format.numbers_picked
        ]
        jackpot_part = Decimal(0)
        if jackpot_winners:
            jackpot_part = (
                jackpots[lottery_format.code] / len(jackpot_winners)
            ).quantize(CENT, ROUND_HALF_UP)
            jackpots[lottery_format.code] = lottery_format.jackpot_seed

        for ticket, matched in matches:
            if matched == lottery_format.numbers_picked:
                amount = jackpot_part
            elif matched in lottery_format.prize_multipliers:
                amount = (
                    draw_terms.ticket_price * lottery_format.prize_multipliers[matched]
                )
            else:
                continue
            status, paid_at = prize_payment(rng, ticket, amount)
            prizes.append(
                Prize(
                    len(prizes) + 1, ticket.ticket_id, matched, amount, status, paid_at
                )
            )
    return prizes


def write_csv(
    file_name: str, header: Sequence[str], rows: Iterable[Sequence[object]]
) -> None:
    with (DATA_DIR / file_name).open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(header)
        writer.writerows(rows)


def lottery_row(lottery: Lottery) -> Sequence[object]:
    lottery_format = lottery.lottery_format
    return (
        lottery.lottery_id,
        lottery_format.code,
        lottery_format.name,
        lottery_format.numbers_total,
        lottery_format.numbers_picked,
        lottery_format.terms_history[0].starts_at,
        lottery_format.closed_at,
    )


def terms_rows(lotteries: Sequence[Lottery]) -> Iterable[Sequence[object]]:
    for lottery in lotteries:
        history = lottery.lottery_format.terms_history
        ends = [version.starts_at for version in history[1:]] + [OPEN_END_DTTM]
        for terms_id, version, ends_at in zip(
            lottery.terms_ids, history, ends, strict=True
        ):
            yield (
                terms_id,
                lottery.lottery_id,
                version.ticket_price,
                version.jackpot_share,
                version.starts_at,
                ends_at,
            )


def export(
    users: Sequence[User],
    lotteries: Sequence[Lottery],
    draws: Sequence[Draw],
    tickets: Sequence[Ticket],
    prizes: Sequence[Prize],
) -> None:
    DATA_DIR.mkdir(exist_ok=True)
    write_csv(
        "users.csv",
        (
            "user_id",
            "email",
            "full_name",
            "phone",
            "birth_date",
            "city",
            "registered_at",
            "status",
        ),
        (
            (
                user.user_id,
                user.email,
                user.full_name,
                user.phone,
                user.birth_date,
                user.city,
                user.registered_at,
                user.status,
            )
            for user in users
        ),
    )
    write_csv(
        "lotteries.csv",
        (
            "lottery_id",
            "code",
            "name",
            "numbers_total",
            "numbers_picked",
            "launched_at",
            "closed_at",
        ),
        map(lottery_row, lotteries),
    )
    write_csv(
        "lottery_terms.csv",
        (
            "terms_id",
            "lottery_id",
            "ticket_price",
            "jackpot_share",
            "start_dttm",
            "end_dttm",
        ),
        terms_rows(lotteries),
    )
    write_csv(
        "draws.csv",
        ("draw_id", "lottery_id", "draw_number", "scheduled_at", "drawn_at", "status"),
        (
            (
                draw.draw_id,
                draw.lottery.lottery_id,
                draw.draw_number,
                draw.scheduled_at,
                draw.drawn_at,
                draw.status,
            )
            for draw in draws
        ),
    )
    write_csv(
        "draw_numbers.csv",
        ("draw_id", "number"),
        (
            (draw.draw_id, number)
            for draw in draws
            for number in sorted(draw.winning_numbers)
        ),
    )
    write_csv(
        "tickets.csv",
        (
            "ticket_id",
            "user_id",
            "draw_id",
            "purchased_at",
            "price_paid",
            "channel",
            "status",
        ),
        (
            (
                ticket.ticket_id,
                ticket.user_id,
                ticket.draw.draw_id,
                ticket.purchased_at,
                ticket.price_paid,
                ticket.channel,
                ticket.status,
            )
            for ticket in tickets
        ),
    )
    write_csv(
        "ticket_numbers.csv",
        ("ticket_id", "number"),
        (
            (ticket.ticket_id, number)
            for ticket in tickets
            for number in sorted(ticket.numbers)
        ),
    )
    write_csv(
        "prizes.csv",
        ("prize_id", "ticket_id", "matched_count", "amount", "status", "paid_at"),
        (
            (
                prize.prize_id,
                prize.ticket_id,
                prize.matched_count,
                prize.amount,
                prize.status,
                prize.paid_at,
            )
            for prize in prizes
        ),
    )


rng = random.Random(RANDOM_SEED)
users = generate_users(rng)
lotteries = build_lotteries()
draws = generate_draws(rng, lotteries)
tickets = generate_tickets(rng, users, draws)
prizes = generate_prizes(rng, draws, tickets)
export(users, lotteries, draws, tickets, prizes)
print(
    f"users={len(users)} lotteries={len(lotteries)} draws={len(draws)} tickets={len(tickets)} prizes={len(prizes)}"
)
