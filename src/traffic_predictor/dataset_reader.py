import csv
import sys
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class CsvRow:
    """Single CSV row with replay metadata."""
    row_index: int              # 1-based index in the 'rows' list
    raw: List[str]              # Original CSV row
    csv_time: Optional[float]   # Parsed 'Time' value, if available
    relative_time: Optional[float]  # (csv_time - base_time) / time_scale
    should_transmit: bool       # Derived from 'Transmition Flags'
    payload: str                # Joined payload columns (as in the UDP message)


class CsvReplayReader:
    """
    CSV reader for DPDR-like trajectories.

    Responsibilities:
      - Open CSV and read header.
      - Resolve indices for Time and Transmition Flags.
      - Identify payload columns.
      - Load all rows into memory.
      - Compute base time for relative scheduling.
      - Provide getNext() to fetch the next row with metadata.
    """

    def __init__(
        self,
        csv_path: str,
        *,
        time_column: str = "Time",
        flag_column: str = "Transmition Flags",
        time_scale: float = 1.0,
        verbose: bool = True,
    ) -> None:
        self.csv_path = csv_path
        self.time_column = time_column
        self.flag_column = flag_column
        self.time_scale = time_scale
        self.verbose = verbose

        self.header: List[str] = []
        self.time_idx: Optional[int] = None
        self.flag_idx: Optional[int] = None
        self.payload_indices: List[int] = []
        self.rows: List[List[str]] = []

        self.base_csv_time: Optional[float] = None
        self._cursor: int = 0  # 0-based index into self.rows

        self._load_all_rows()
        self._compute_base_time()

    # ------------------------
    # Internal helpers
    # ------------------------
    def _vprint(self, msg: str) -> None:
        if self.verbose:
            print(msg)

    @staticmethod
    def _safe_float(value, default=None):
        try:
            return float(value)
        except Exception:
            return default

    def _parse_header(self, header: List[str]):
        """Resolve indices for time column, flag column, and payload columns."""
        header_to_index = {name.strip(): idx for idx, name in enumerate(header)}

        self.time_idx = header_to_index.get(self.time_column)
        self.flag_idx = header_to_index.get(self.flag_column)

        self.payload_indices = [
            i
            for i in range(len(header))
            if i not in {self.time_idx, self.flag_idx}
        ]

        self._vprint(f"CSV Header: {','.join(header)}")
        self._vprint(
            f"Resolved columns -> time_idx={self.time_idx}, "
            f"flag_idx={self.flag_idx}, payload_cols={self.payload_indices}"
        )

    def _load_all_rows(self) -> None:
        """Load entire CSV and populate header, indices, and rows."""
        try:
            with open(self.csv_path, "r", newline="") as f:
                reader = csv.reader(f)
                header = next(reader, None)
                if not header:
                    print("Error: CSV has no header")
                    sys.exit(1)

                self.header = header
                self._parse_header(header)

                self.rows = [row for row in reader if row]

        except FileNotFoundError:
            print(f"Error: CSV file '{self.csv_path}' not found")
            sys.exit(1)

    def _compute_base_time(self) -> None:
        """Find the first valid Time value to use as base for relative timing."""
        if self.time_idx is None:
            self.base_csv_time = None
            return

        for r in self.rows:
            if self.time_idx < len(r):
                t = self._safe_float(r[self.time_idx], None)
                if t is not None:
                    self.base_csv_time = t
                    break

        self._vprint(f"Base CSV time: {self.base_csv_time}")

    # ------------------------
    # Public API
    # ------------------------
    def reset(self) -> None:
        """Reset internal pointer to start of rows."""
        self._cursor = 0

    def getNext(self) -> Optional[CsvRow]:
        """
        Return the next CsvRow object, or None if no more rows.

        This mirrors your original logic:
          - should_transmit from Transmition Flags (> 0.0)
          - payload = join(payload_indices)
          - csv_time from Time column
          - relative_time = (csv_time - base_csv_time) / time_scale
        """
        if self._cursor >= len(self.rows):
            return None

        row = self.rows[self._cursor]
        row_index = self._cursor + 1  # 1-based, like enumerate(start=1)
        self._cursor += 1

        # Time and relative time
        csv_time = None
        relative_time = None

        if self.time_idx is not None and self.time_idx < len(row):
            csv_time = self._safe_float(row[self.time_idx], None)

        if (
            csv_time is not None
            and self.base_csv_time is not None
            and self.time_scale > 0.0
        ):
            relative_time = max(
                0.0, (csv_time - self.base_csv_time) / max(1e-9, self.time_scale)
            )

        # Transmission flag
        should_transmit = True
        if self.flag_idx is not None and self.flag_idx < len(row):
            should_transmit = (self._safe_float(row[self.flag_idx], 0.0) or 0.0) > 0.0

        # Payload string (same as you send over UDP)
        payload = ",".join(
            row[idx] for idx in self.payload_indices if idx < len(row)
        )

        return CsvRow(
            row_index=row_index,
            raw=row,
            csv_time=csv_time,
            relative_time=relative_time,
            should_transmit=should_transmit,
            payload=payload,
        )

    # Optional: make it iterable
    def __iter__(self):
        self.reset()
        return self

    def __next__(self) -> CsvRow:
        row = self.getNext()
        if row is None:
            raise StopIteration
        return row
