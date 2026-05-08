defmodule Nexus.RBACTest do
  @moduledoc """
  Unit tests for Nexus.RBAC platform role helpers.

  These tests use struct literals — no DB access required for the
  platform-role functions since they operate on an in-memory field.
  """
  use Nexus.DataCase, async: true

  alias Nexus.Identity.Projections.User
  alias Nexus.RBAC

  defp build_user(attrs \\ %{}) do
    struct(User, Map.merge(%{id: Uniq.UUID.uuid7(), status: "active"}, attrs))
  end

  # ── has_platform_role?/2 ─────────────────────────────────────────────────

  describe "has_platform_role?/2" do
    test "returns true when user holds the exact role (atom)" do
      user = build_user(%{platform_role: "super_admin"})
      assert RBAC.has_platform_role?(user, :super_admin)
    end

    test "returns true when user holds the exact role (string)" do
      user = build_user(%{platform_role: "super_admin"})
      assert RBAC.has_platform_role?(user, "super_admin")
    end

    test "returns false when user holds a different role" do
      user = build_user(%{platform_role: "platform_support"})
      refute RBAC.has_platform_role?(user, :super_admin)
    end

    test "returns false when platform_role is nil" do
      user = build_user(%{platform_role: nil})
      refute RBAC.has_platform_role?(user, :super_admin)
    end

    test "returns true when role is in allowed list" do
      user = build_user(%{platform_role: "platform_support"})
      assert RBAC.has_platform_role?(user, [:super_admin, :platform_support])
    end

    test "returns false when role is not in allowed list" do
      user = build_user(%{platform_role: nil})
      refute RBAC.has_platform_role?(user, [:super_admin, :platform_support])
    end

    test "returns false for non-User structs" do
      refute RBAC.has_platform_role?(%{platform_role: "super_admin"}, :super_admin)
    end
  end

  # ── super_admin?/1 ───────────────────────────────────────────────────────

  describe "super_admin?/1" do
    test "returns true for super_admin" do
      user = build_user(%{platform_role: "super_admin"})
      assert RBAC.super_admin?(user)
    end

    test "returns false for platform_support" do
      user = build_user(%{platform_role: "platform_support"})
      refute RBAC.super_admin?(user)
    end

    test "returns false when no platform_role" do
      user = build_user(%{platform_role: nil})
      refute RBAC.super_admin?(user)
    end
  end

  # ── platform_staff?/1 ────────────────────────────────────────────────────

  describe "platform_staff?/1" do
    test "returns true for super_admin" do
      user = build_user(%{platform_role: "super_admin"})
      assert RBAC.platform_staff?(user)
    end

    test "returns true for platform_support" do
      user = build_user(%{platform_role: "platform_support"})
      assert RBAC.platform_staff?(user)
    end

    test "returns false when no platform_role" do
      user = build_user(%{platform_role: nil})
      refute RBAC.platform_staff?(user)
    end

    test "returns false for an unrecognized role string" do
      user = build_user(%{platform_role: "org_admin"})
      refute RBAC.platform_staff?(user)
    end
  end
end
