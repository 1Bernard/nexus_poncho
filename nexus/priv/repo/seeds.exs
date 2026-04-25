alias Nexus.Marketing.Projections.AccessRequest
alias Nexus.Repo

requests = [
  %{
    id: Uniq.UUID.uuid7(),
    name: "Alexandra Wren",
    email: "a.wren@blackrock-treasury.com",
    organization: "BlackRock Treasury Solutions",
    job_title: "Head of Treasury Operations",
    treasury_volume: "gt_1b",
    subsidiaries: "100_plus",
    message:
      "We manage cross-border liquidity for 140+ subsidiaries across 38 countries. Seeking a platform that can handle real-time netting at institutional scale with full FIPS compliance.",
    status: "approved"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Marcus Delacroix",
    email: "m.delacroix@statestreetcorp.com",
    organization: "State Street Global Advisors",
    job_title: "VP Corporate Treasury",
    treasury_volume: "gt_1b",
    subsidiaries: "51_100",
    message:
      "Currently evaluating platforms to replace our legacy intercompany settlement system. Equinox's biometric auth model and automated netting are directly aligned with our 2026 modernization roadmap.",
    status: "under_review"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Priya Nair",
    email: "priya.nair@tata-treasury.in",
    organization: "Tata Sons Treasury",
    job_title: "Group Treasury Director",
    treasury_volume: "500m_1b",
    subsidiaries: "51_100",
    message:
      "Tata Sons operates 66 subsidiary entities across Asia-Pacific and EMEA. We need consolidated cash visibility and automated intercompany loan accounting.",
    status: "under_review"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Jonathan Sable",
    email: "jsable@nuveen-capital.com",
    organization: "Nuveen Capital Management",
    job_title: "Chief Financial Officer",
    treasury_volume: "100m_500m",
    subsidiaries: "21_50",
    message: nil,
    status: "pending"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Fatima Al-Rashid",
    email: "f.alrashid@mubadala.ae",
    organization: "Mubadala Investment Company",
    job_title: "Treasury Risk Manager",
    treasury_volume: "gt_1b",
    subsidiaries: "100_plus",
    message:
      "Sovereign wealth fund with 120+ portfolio entities. Require institutional-grade cash pooling and real-time position reporting for regulatory filings.",
    status: "pending"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Tobias Kremmer",
    email: "t.kremmer@siemens-treasury.de",
    organization: "Siemens AG Treasury",
    job_title: "Senior Treasury Analyst",
    treasury_volume: "gt_1b",
    subsidiaries: "100_plus",
    message:
      "Siemens runs in-house banking for 200+ entities. We are piloting next-gen TMS integrations and Equinox's event-driven model is a strong architectural fit.",
    status: "approved"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Rachel Okonkwo",
    email: "r.okonkwo@dangote-group.com",
    organization: "Dangote Group",
    job_title: "Group Head of Finance",
    treasury_volume: "500m_1b",
    subsidiaries: "21_50",
    message:
      "Pan-African conglomerate with significant FX exposure and intercompany complexity. Looking for a modern alternative to our current spreadsheet-driven netting process.",
    status: "pending"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Wei Zhang",
    email: "w.zhang@cosco-finance.cn",
    organization: "COSCO Shipping Finance",
    job_title: "Treasury Manager",
    treasury_volume: "100m_500m",
    subsidiaries: "6_20",
    message: nil,
    status: "rejected",
    rejection_reason:
      "Insufficient regulatory documentation for cross-border onboarding. Entity is registered in a jurisdiction not currently supported."
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Ingrid Bjornstad",
    email: "i.bjornstad@equinor-treasury.no",
    organization: "Equinor Treasury",
    job_title: "Cash Management Lead",
    treasury_volume: "gt_1b",
    subsidiaries: "51_100",
    message:
      "Energy sector treasury with significant multi-currency exposure. Need automated netting between 80 entities across Norway, US, Brazil, and UK.",
    status: "pending"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Daniel Ferretti",
    email: "d.ferretti@ferrari-finanza.it",
    organization: "Ferrari N.V. Treasury",
    job_title: "Treasury Controller",
    treasury_volume: "100m_500m",
    subsidiaries: "6_20",
    message:
      "Automotive group with European and North American treasury centres. Seeking real-time FX netting and an audit trail that meets ESMA reporting standards.",
    status: "under_review"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Aiko Tanaka",
    email: "a.tanaka@softbank-treasury.jp",
    organization: "SoftBank Group Treasury",
    job_title: "International Treasury Lead",
    treasury_volume: "gt_1b",
    subsidiaries: "100_plus",
    message:
      "SoftBank's Vision Fund portfolio generates complex intercompany flows across 300+ entities. We need a platform purpose-built for multi-entity netting at scale.",
    status: "approved"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Samuel Osei",
    email: "samuel.osei@gmail.com",
    organization: "Osei Consulting LLC",
    job_title: "Financial Advisor",
    treasury_volume: "lt_10m",
    subsidiaries: "1_5",
    message: nil,
    status: "rejected",
    rejection_reason:
      "Platform is designed for institutional treasury operations at scale. This application does not meet the minimum treasury volume or entity count requirements for onboarding."
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Claire Beaumont",
    email: "c.beaumont@lvmh-treasury.fr",
    organization: "LVMH Moët Hennessy",
    job_title: "Group Treasury Director",
    treasury_volume: "gt_1b",
    subsidiaries: "100_plus",
    message:
      "LVMH operates 75+ Maisons across luxury, retail, and hospitality. Intercompany cash pooling and FX netting across EUR, USD, CNY, and JPY is a daily operational need.",
    status: "pending"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "James Holt",
    email: "j.holt@bhpgroup.com",
    organization: "BHP Group Treasury",
    job_title: "Senior Treasury Manager",
    treasury_volume: "gt_1b",
    subsidiaries: "51_100",
    message:
      "Mining and resources group with subsidiaries across Australia, Chile, South Africa, and Canada. Require fully auditable intercompany loan and netting platform.",
    status: "archived"
  },
  %{
    id: Uniq.UUID.uuid7(),
    name: "Nadia Petrov",
    email: "n.petrov@gazprombank-treasury.ru",
    organization: "Sovcombank Treasury",
    job_title: "Head of Liquidity Management",
    treasury_volume: "500m_1b",
    subsidiaries: "21_50",
    message: nil,
    status: "rejected",
    rejection_reason:
      "Sanctioned jurisdiction. Application cannot be processed under current OFAC compliance policy."
  }
]

now = DateTime.utc_now()

Enum.each(requests, fn attrs ->
  record = struct(AccessRequest, Map.merge(attrs, %{created_at: now, updated_at: now}))
  Repo.insert!(record, on_conflict: :nothing, conflict_target: :email)
end)

IO.puts("Seeded #{length(requests)} access requests.")
