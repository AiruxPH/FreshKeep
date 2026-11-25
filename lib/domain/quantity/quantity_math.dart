/// Exact two-decimal quantity arithmetic using scaled integer hundredths so
/// measured units (`g`, `mL`) never suffer floating-point drift on subtraction,
/// depletion, or undo.
const int kQuantityScale = 100;
const double kMaxQuantity = 1000000000;

int toScaledUnits(num value) => (value * kQuantityScale).round();

double fromScaledUnits(int scaled) => scaled / kQuantityScale;

double normalizeQuantity(num value) => fromScaledUnits(toScaledUnits(value));

double addQuantities(num a, num b) =>
    fromScaledUnits(toScaledUnits(a) + toScaledUnits(b));

double subtractQuantities(num a, num b) =>
    fromScaledUnits(toScaledUnits(a) - toScaledUnits(b));
