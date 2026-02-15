## Plan: Document Actuarial Calculation Functions

Create a comprehensive markdown document cataloging all actuarial calculation functions across the valuation model, organizing them by purpose and functionality to serve as a reference guide for the pension fund valuation system.

### Steps

1. **Create the main document structure** in [actuarial_functions.md](actuarial_functions.md) with sections for each of the 18 function categories identified: mortality/survival functions, annuity calculations, pension benefits, gratuity, present values, accrued liabilities, normal costs, salary projections, medical benefits, cash flows, probabilities, restoration, electricity benefits, leave encashment, pensioner-specific calculations, discount factors, and decrement tables.

2. **Document each function category** with detailed tables containing function names, source files with links (e.g., [generic.py](avms-fastapi-docker/app/valuations/generic.py)), descriptions, mathematical formulas where applicable, and key parameters with their data types and meanings.

3. **Add implementation details** including cross-references between related functions (e.g., how `tPx`, `tPy`, and `tPxy` relate), common usage patterns, and dependencies on lookup tables (mortality_table, decrement_table, commutation_factors).

4. **Include a summary section** with statistics (100+ functions across 6 main files), a quick reference index organized by use case (calculating pension benefits, projecting cash flows, determining survival probabilities), and file location map.

### Further Considerations

1. **Level of mathematical detail?** Should formulas include full actuarial notation (ₜPₓ, äₓ:ᵧ̅) or simplified explanations for non-actuaries?
2. **Code examples?** Include sample function calls with real parameter values to demonstrate usage?
3. **Excel formula mappings?** Several functions reference Excel cell formulas in comments - document these mappings for validation purposes?

## Plan: Document Actuarial Calculation Functions

Create a comprehensive markdown document cataloging all actuarial calculation functions across the valuation model, with full mathematical notation equivalents for each function.

### Steps

1. **Create the main document structure** in actuarial_functions.md with sections for each of the 18 function categories: mortality/survival functions, annuity calculations, pension benefits, gratuity, present values (PVFBTA/PVFBAA), accrued liabilities, normal costs, salary projections, medical benefits, cash flows, probabilities, restoration, electricity benefits, leave encashment, pensioner-specific calculations, discount factors, and decrement tables.

2. **Document mortality/survival functions** with mathematical equivalents:
   - `lookup_mortality()` → Lₓ, qₓ lookup
   - `tPx()` → ₜpₓ = Lₓ₊ₜ / Lₓ
   - `tPy()` → ₜpᵧ = Lᵧ₊ₜ / Lᵧ
   - `tPxy()` → ₜpₓᵧ = ₜpₓ × ₜpᵧ

3. **Document annuity functions** with mathematical equivalents:
   - `last_survivor_annuity()` → äₓᵧ⁽¹²⁾ (joint-life last survivor annuity)
   - `last_survivor_annuity_ar()` → äₓᵧ:n̅⁽¹²⁾ (limited spouse benefit)
   - `annuity_monthly()` → äₓ⁽¹²⁾ = Σ(ₜpₓ × vᵗ × pmt)
   - `annuity_monthly_n_years()` → äₓ:n̅⁽¹²⁾ (n-year temporary)
   - `restoration()` → vⁿ × (1+i)ⁿ × [ₜpₓ × ₜpᵧ × äₓ₊ₙ,ᵧ₊ₙ + ₜpₓ(1-ₜpᵧ)äₓ₊ₙ + ₜpᵧ(1-ₜpₓ)äᵧ₊ₙ × SP]

4. **Document pension benefit calculations**:
   - `compute_pension_benefit_pension_ret()` → max(min_pension, accrual_rate × service × salary)
   - `compute_pension_benefit_pension_with()` → pension × decrease_factor
   - `compute_pension_benefit_pension_death()` → death_factor × pension
   - `compute_pension_benefit_pension_illhealth()` → illhealth_factor × pension

5. **Document present value (PVFBTA) calculations**:
   - `compute_pvfbta_gratuity_*()` → qₓᵈ × GF × service × salary
   - `compute_pvfbta_pension_ret()` → 12 × qₓʳ × Pension × [(1-c)äₓ × π + c × CF]
   - `compute_pvfbta_pension_with()` → 12 × qₓʷ × Pension × [(1-c)äₓ × π + c × (CF + äᵣ × π)]
   - `compute_pvfbta_pension_death()` → 12 × qₓᵈ × Pension × [AP × äₓ × π + c × CF]
   - `compute_pvfbta_orderly_*()` → 12 × qₓ × äₓ × OA

6. **Document present value (PVFBAA) calculations**:
   - `compute_pvfbaa_ret()` → PVFBTA_ret × v
   - `compute_pvfbaa_with()` → PVFBAA_prev × v × (1 - qₓ - hd)
   - `compute_pvfbaa_death()` → PVFBAA_prev × v × (1 - qₓ - hd)

7. **Document accrued liability calculations**:
   - `compute_accrued_liability_ret()` → PVFBAA_ret × min(PS, service_cap) / service_cap

8. **Document normal cost calculations**:
   - `compute_normal_cost_*()` → Accrued_Liability / service_cap

9. **Document salary projection functions**:
   - `_compute_sif_lt6()` → ∏(1 + SIᵢ) for i < 6
   - `_compute_sif_gt6()` → (1 + SIR)ᵗ for t ≥ 6
   - `_compute_salary()` → base_salary × SIF × (month_factor)
   - `n_years_avg_salary()` → (Σsalaryᵢ) / n
   - `compute_decrease_factor()` → max(1 - reduction × years_early, min_factor)

10. **Document cash flow probability functions**:
    - `compute_probabilities_pxpy()` → ₁pₓ × ₁pᵧ
    - `compute_probabilities_pxqy()` → ₁pₓ × (1 - ₁pᵧ)
    - `compute_probabilities_pyqx()` → (1 - ₁pₓ) × ₁pᵧ
    - `compute_probabilities_px()` → ₁pₓ
    - `compute_probabilities_py()` → ₁pᵧ

11. **Document cash flow calculations**:
    - `calculate_cashflow_pxpy()` → Pension × (1+i)ᵗ × ₜpₓᵧ + restoration
    - `calculate_cashflows_monthly()` → Σ(cf_pxpy + cf_pxqy + cf_pyqx + cf_px + cf_py)
    - `calculate_cashflows_lump_sum()` → commutation + gratuity components
    - `calculate_cashflows_medical_*()` → medical_benefit × probabilities × äₓ

12. **Document medical, electricity, and leave encashment** with PVFBTA, PVFBAA, accrued liability, and normal cost patterns.

13. **Document discount factor calculations**:
    - v = 1/(1+DR), vᵗ = (1+DR)⁻ᵗ

14. **Add notation legend** explaining all actuarial symbols (ₜpₓ, qₓ, äₓ⁽¹²⁾, v, CF, π).

### Further Considerations

1. **Notation style?** Use standard actuarial notation (SOA/IFoA style) or simplified subscript notation?
2. **Include derivations?** Show how complex formulas like `restoration()` are built from components?
3. **Group by decrement type?** Organize PVFBTA/PVFBAA/AL/NC sections by retirement/withdrawal/death/illhealth?


## Plan: Document Actuarial Calculation Functions (Generic N-Level Approach)

Create a comprehensive markdown document cataloging all actuarial calculation functions with a **generic, parameterized design** where decrement types (retirement, withdrawal, death, illhealth, etc.) are passed as parameters rather than hardcoded into function names.

### Steps

1. **Create the main document structure** in actuarial_functions.md organized by calculation layers:
   - Layer 1: Primitive functions (mortality lookup, survival probabilities)
   - Layer 2: Intermediate functions (annuities, benefit calculations)
   - Layer 3: Present value functions (PVFBTA, PVFBAA)
   - Layer 4: Liability functions (Accrued Liability, Normal Cost)
   - Layer 5: Cash flow projections

---

2. **Document mortality/survival functions (Layer 1)** — Generic lookup with any property:
   - `lookup_mortality(table, age, property)` → Lₓ, qₓ, or any column lookup
   - `tPx(age, t, setback, table)` → ₜpₓ = Lₓ₊ₜ / Lₓ (generic survival for any individual)
   - `tPy(age, t, setback, table)` → ₜpᵧ = Lᵧ₊ₜ / Lᵧ (spouse survival)
   - `tPxy(age_x, age_y, t, setback_x, setback_y, table)` → ₜpₓᵧ = ₜpₓ × ₜpᵧ (joint survival)
   - **Generic form**: `tP(age, t, setback, table)` → ₜp = L(age+t) / L(age)

---

3. **Document annuity functions (Layer 2)** — Parameterized by payment frequency, term, and lives:
   - `annuity_monthly(age, setback, i, DR, ...)` → äₓ⁽¹²⁾ = Σₜ(ₜpₓ × vᵗ × pmt)
   - `annuity_monthly_n_years(age, setback, n, ...)` → äₓ:n̅⁽¹²⁾ (n-year temporary)
   - `last_survivor_annuity(age, ...)` → äₓᵧ⁽¹²⁾ (joint-life last survivor)
   - `last_survivor_annuity_ar(age, ..., spouse_limit)` → äₓᵧ:n̅⁽¹²⁾ (limited spouse benefit)
   - `restoration(age, n, ...)` → vⁿ(1+i)ⁿ × [ₜpₓₜpᵧäₓ₊ₙ,ᵧ₊ₙ + ₜpₓ(1-ₜpᵧ)äₓ₊ₙ + ₜpᵧ(1-ₜpₓ)äᵧ₊ₙ×SP]
   - **Generic form**: `annuity(age, setback, term, frequency, type, table)` → ä⁽ᵐ⁾

---

4. **Document pension benefit calculations (Layer 2)** — Generic factor-based:
   - **Propose**: `compute_benefit_by_factor(benefit_type, decrement_type, params)` → Benefit × Factor
   - **Mathematical form**: B(d) = f(service, salary, accrual_rate, factor_d)
   - Where `decrement_type` ∈ {retirement, withdrawal, death, illhealth, ...}
   - Current specific functions map to generic:
     - `compute_pension_benefit_pension_ret()` → `compute_benefit('pension', 'ret', ...)`
     - `compute_pension_benefit_pension_with()` → `compute_benefit('pension', 'with', ...)`
     - `compute_pension_benefit_pension_death()` → `compute_benefit('pension', 'death', ...)`
     - `compute_pension_benefit_pension_illhealth()` → `compute_benefit('pension', 'illhealth', ...)`

---

5. **Document present value PVFBTA calculations (Layer 3)** — Generic by decrement type `d`:
   - **Generic form**: `compute_pvfbta(benefit_type, decrement_type, params)`
   - **Mathematical notation**: PVFBTA(d) = f(qₓᵈ, Benefit, AnnuityFactor, CommutationFactor)
   
   | Benefit Type | Formula |
   |--------------|---------|
   | Gratuity | PVFBTA_gratuity(d) = qₓᵈ × GF_d × TS_d × Salary |
   | Pension | PVFBTA_pension(d) = 12 × qₓᵈ × Pension_d × [(1-c_d)ä_d × π + c_d × CF_d] |
   | Orderly | PVFBTA_orderly(d) = 12 × qₓᵈ × ä_d × OA |
   | Medical | PVFBTA_medical(d) = qₓᵈ × MedicalBenefit × ä_medical_d |
   | Electricity | PVFBTA_elec(d) = qₓᵈ × AvgCost × ä_elec_d |
   | Leave | PVFBTA_leave(d) = qₓᵈ × TotalLeave × Salary × LPR |

   Where `d` ∈ {ret, with, death, illhealth}

---

6. **Document present value PVFBAA calculations (Layer 3)** — Generic accumulation:
   - **Generic form**: `compute_pvfbaa(benefit_type, decrement_type, params)`
   - **Mathematical notation**:
     - PVFBAA_ret(d) = PVFBTA(d) × v
     - PVFBAA_accum(d) = PVFBAA_prev(d) × v × (1 - Σqₓ - hd)
   - Applies uniformly across all benefit types and decrement types

---

7. **Document accrued liability calculations (Layer 4)** — Generic by decrement type:
   - **Generic form**: `compute_accrued_liability(benefit_type, decrement_type, params)`
   - **Mathematical notation**: AL(d) = PVFBAA(d) × min(PS, service_cap) / service_cap
   - Applies to all combinations of benefit_type × decrement_type

---

8. **Document normal cost calculations (Layer 4)** — Generic by decrement type:
   - **Generic form**: `compute_normal_cost(benefit_type, decrement_type, params)`
   - **Mathematical notation**: NC(d) = AL(d) / service_cap
   - Applies uniformly across all benefit and decrement combinations

---

9. **Document salary projection functions (Layer 2)**:
   - `_compute_sif_lt6(sal_index, si_list)` → ∏ᵢ₌₁ⁿ(1 + SIᵢ) for n < 6
   - `_compute_sif_gt6(age, sal_index, SIR)` → (1 + SIR)ᵗ for t ≥ 6
   - `_compute_hs(sal_index, si_list)` → half-year salary factor
   - `_compute_salary(base, months, sif_lt6, sif_gt6, hs)` → Salary = base × SIF × month_factor
   - `_compute_salary_ret(sif_gt6)` → Salary_ret = pay × sif_gt6
   - `n_years_avg_salary(current, prev_salaries, n)` → (Σᵢsalaryᵢ) / n
   - `compute_decrease_factor(age, ret_age, factor, max)` → max(1 - factor × years_early, 1-max)

---

10. **Document cash flow probability functions (Layer 2)** — Joint life probabilities:
    - `compute_probabilities_pxpy(age_x, age_y)` → ₁pₓ × ₁pᵧ (both survive)
    - `compute_probabilities_pxqy(age_x, age_y)` → ₁pₓ × (1 - ₁pᵧ) (x survives, y dies)
    - `compute_probabilities_pyqx(age_x, age_y)` → (1 - ₁pₓ) × ₁pᵧ (y survives, x dies)
    - `compute_probabilities_px(age_x)` → ₁pₓ (x survives)
    - `compute_probabilities_py(age_y)` → ₁pᵧ (y survives)
    - **Generic form**: `compute_probability(survival_state, ages, setbacks, table)`

---

11. **Document cash flow calculations (Layer 5)** — Projection functions:
    - `calculate_cashflow_pxpy(...)` → CF_pxpy = Pension × (1+i)ᵗ × ₜpₓᵧ + Restoration
    - `calculate_cashflow_pxqy(...)` → CF_pxqy = prev_cf × prob_pxqy
    - `calculate_cashflow_pyqx(...)` → CF_pyqx = prev_cf × prob_pyqx × spouse_factor
    - `calculate_cashflow_px(...)` → CF_px = restoration_tpx_tqy component
    - `calculate_cashflow_py(...)` → CF_py = restoration_tpy_tqy component
    - `calculate_cashflows_monthly(...)` → CF_total = Σ(CF_pxpy + CF_pxqy + CF_pyqx + CF_px + CF_py)
    - `calculate_cashflows_lump_sum(...)` → CF_lump = commutation + gratuity_components
    - `calculate_cashflows_percent_change(...)` → ΔCF = (CF_current - CF_prev) / CF_prev
    - `calculate_cashflows_medical_*(...)` → CF_medical = medical_benefit × prob × ä_medical

---

12. **Document restoration calculations (Layer 2)** — SUMIF equivalents:
    - `compute_restoration_amount_tpxy(ages, current_age, tpxy_list)` → Σ(tpxy where age matches)
    - `compute_restoration_amount_tpx_times_tqy(ages, current_age, values)` → Σ(tpx×tqy where age matches)
    - `compute_restoration_amount_tpy_times_tqy(ages, current_age, values)` → Σ(tpy×tqy where age matches)

---

13. **Document discount factor calculations (Layer 1)**:
    - Discount factor: v = 1/(1+DR)
    - Period discount: vᵗ = (1+DR)⁻ᵗ
    - Half-year discount: v^(m/12) where m = months
    - Effective rate: i_eff = (1+DR)^(1/m) - 1

---

14. **Add comprehensive notation legend**:

    | Symbol | Description |
    |--------|-------------|
    | ₜpₓ | Probability of survival from age x to x+t |
    | qₓᵈ | Probability of decrement d at age x |
    | äₓ⁽¹²⁾ | Annuity payable monthly (12 times/year) |
    | äₓ:n̅⁽¹²⁾ | n-year temporary annuity payable monthly |
    | äₓᵧ | Joint-life last survivor annuity |
    | v | Discount factor = 1/(1+DR) |
    | vᵗ | t-year discount factor |
    | CF | Commutation factor |
    | π | Pension increase factor |
    | GF | Gratuity factor |
    | OA | Orderly allowance |
    | SP | Spouse pension percentage |
    | Lₓ | Number of lives at age x |
    | d | Decrement type ∈ {ret, with, death, illhealth} |

---

15. **Include function hierarchy diagram** showing dependencies:
    ```
    Layer 5: Cash Flow Projections
        ↑
    Layer 4: Accrued Liability, Normal Cost
        ↑
    Layer 3: PVFBTA, PVFBAA
        ↑
    Layer 2: Annuities, Benefits, Salary, Probabilities
        ↑
    Layer 1: Mortality Lookup, Survival, Discount Factors
    ```

---

### Further Considerations

1. **Generic function refactoring?** Propose consolidating specific functions into parameterized versions (e.g., `compute_pvfbta(benefit_type, decrement_type)` instead of 24+ separate functions)?

2. **Configuration-driven approach?** Document how benefit types and decrement types could be defined in configuration files for extensibility?

3. **Validation mappings?** Include Excel cell references for each formula to enable cross-validation with existing spreadsheets?