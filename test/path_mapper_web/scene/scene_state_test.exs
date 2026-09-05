defmodule PathMapperWeb.Scene.SceneStateTest do
  use ExUnit.Case, async: true

  alias PathMapperWeb.Scene.SceneState

  # A map larger than the viewport at zoom 1.0, so both axes overflow and
  # anchoring binds on both. Deliberately asymmetric so a swapped x/y fails.
  @overflow {800, 600, 1200.0, 900.0, 1000.0, 700.0}

  defp origin_x(state, base_width, viewport_width),
    do: SceneState.rendered_origin(elem(state.pan, 0), base_width * state.zoom, viewport_width)

  defp origin_y(state, base_height, viewport_height),
    do: SceneState.rendered_origin(elem(state.pan, 1), base_height * state.zoom, viewport_height)

  # Where the map point that was under the cursor sits after a zoom. If
  # anchoring holds, this equals the cursor position.
  defp anchored_x(before_state, after_state, cursor, base, viewport) do
    fraction = (cursor - origin_x(before_state, base, viewport)) / (base * before_state.zoom)
    origin_x(after_state, base, viewport) + fraction * base * after_state.zoom
  end

  defp anchored_y(before_state, after_state, cursor, base, viewport) do
    fraction = (cursor - origin_y(before_state, base, viewport)) / (base * before_state.zoom)
    origin_y(after_state, base, viewport) + fraction * base * after_state.zoom
  end

  describe "rendered_origin/3" do
    test "centers the map when it fits the viewport, ignoring pan" do
      assert SceneState.rendered_origin(-999, 400, 1000) == 300
      assert SceneState.rendered_origin(0, 400, 1000) == 300
    end

    test "clamps pan so the map cannot be dragged past its edges" do
      # map 1500 wide in a 1000 viewport: pan may range [-500, 0]
      assert SceneState.rendered_origin(-200, 1500, 1000) == -200
      assert SceneState.rendered_origin(-900, 1500, 1000) == -500
      assert SceneState.rendered_origin(300, 1500, 1000) == 0
    end

    test "an exactly-fitting map is centered at the origin" do
      assert SceneState.rendered_origin(-50, 1000, 1000) == 0
    end
  end

  describe "wheel_exponent/3" do
    test "pixel mode scales deltaY by 0.002" do
      assert SceneState.wheel_exponent(-100, 0, false) == 0.2
    end

    test "line mode scales deltaY by 0.05" do
      assert_in_delta SceneState.wheel_exponent(-3, 1, false), 0.15, 0.0001
    end

    test "page mode scales deltaY by 1" do
      assert SceneState.wheel_exponent(-1, 2, false) == 1.0
    end

    test "scrolling down zooms out" do
      assert SceneState.wheel_exponent(100, 0, false) == -0.2
    end

    test "magnitude is honoured rather than reduced to a sign" do
      small = SceneState.wheel_exponent(-50, 0, false)
      large = SceneState.wheel_exponent(-100, 0, false)

      assert_in_delta large, small * 2, 0.0001
    end

    test "ctrl_key amplifies tenfold - this is how trackpad pinch arrives" do
      plain = SceneState.wheel_exponent(-100, 0, false)
      pinch = SceneState.wheel_exponent(-100, 0, true)

      assert_in_delta pinch, plain * 10, 0.0001
    end
  end

  describe "zoom_by_exponent/2 - keyboard and buttons" do
    test "multiplies zoom by 2 ** exponent" do
      state = %SceneState{zoom: 1.0, pan: {0, 0}}

      assert SceneState.zoom_by_exponent(state, 1.0).zoom == 2.0
      assert SceneState.zoom_by_exponent(state, -1.0).zoom == 0.5
    end

    # The whole point of the change: one notch is the same proportional
    # change everywhere. The old additive step was +50% at zoom 0.5 and
    # +9% at zoom 2.75.
    test "the same exponent gives the same ratio at every zoom level" do
      low = %SceneState{zoom: 0.6, pan: {0, 0}}
      high = %SceneState{zoom: 2.0, pan: {0, 0}}

      low_ratio = SceneState.zoom_by_exponent(low, 0.25).zoom / low.zoom
      high_ratio = SceneState.zoom_by_exponent(high, 0.25).zoom / high.zoom

      assert_in_delta low_ratio, high_ratio, 0.0001
    end

    test "leaves pan untouched" do
      state = %SceneState{zoom: 1.0, pan: {-40, -70}}

      assert SceneState.zoom_by_exponent(state, 0.25).pan == {-40, -70}
    end

    test "clamps to the zoom bounds" do
      assert SceneState.zoom_by_exponent(%SceneState{zoom: 2.9}, 1.0).zoom == 3.0
      assert SceneState.zoom_by_exponent(%SceneState{zoom: 0.6}, -1.0).zoom == 0.5
    end

    test "run_event/2 routes :zoom_in and :zoom_out through it at equal rates" do
      state = %SceneState{zoom: 1.0, pan: {0, 0}}

      zoomed_in = SceneState.run_event(state, :zoom_in)
      round_tripped = SceneState.run_event(zoomed_in, :zoom_out)

      assert zoomed_in.zoom > 1.0
      assert_in_delta round_tripped.zoom, 1.0, 0.0001
    end
  end

  describe "zoom_at/3 - cursor-anchored zoom" do
    test "keeps the map point under the cursor fixed when zooming in" do
      state = %SceneState{zoom: 1.0, pan: {0, 0}}
      {cx, cy, bw, bh, vw, vh} = @overflow

      zoomed = SceneState.zoom_at(state, 1.0, @overflow)

      assert zoomed.zoom == 2.0
      assert_in_delta anchored_x(state, zoomed, cx, bw, vw), cx, 0.001
      assert_in_delta anchored_y(state, zoomed, cy, bh, vh), cy, 0.001
    end

    test "keeps the map point under the cursor fixed when zooming out" do
      state = %SceneState{zoom: 2.0, pan: {-500, -400}}
      {cx, cy, bw, bh, vw, vh} = @overflow

      zoomed = SceneState.zoom_at(state, -0.5, @overflow)

      assert_in_delta zoomed.zoom, 1.41421, 0.0001
      assert_in_delta anchored_x(state, zoomed, cx, bw, vw), cx, 0.001
      assert_in_delta anchored_y(state, zoomed, cy, bh, vh), cy, 0.001
    end

    # Anchoring is subordinate to the pan clamp: holding the cursor point
    # can require pushing the map past its own edge, which is not allowed.
    # Zooming far out from a corner is the common case.
    test "the pan clamp wins when holding the anchor would expose an edge" do
      state = %SceneState{zoom: 2.0, pan: {-500, -400}}
      {_cx, _cy, bw, _bh, vw, _vh} = @overflow

      zoomed = SceneState.zoom_at(state, -1.0, @overflow)

      assert zoomed.zoom == 1.0
      # The requested pan is positive (map pushed right of the viewport);
      # rendered_origin clamps it back to 0 so no empty gutter appears.
      assert elem(zoomed.pan, 0) > 0
      assert origin_x(zoomed, bw, vw) == 0
    end

    test "zooming out immediately after zooming in restores the original pan" do
      state = %SceneState{zoom: 1.0, pan: {-100, -80}}

      zoomed_out =
        state
        |> SceneState.zoom_at(1.0, @overflow)
        |> SceneState.zoom_at(-1.0, @overflow)

      assert zoomed_out.zoom == 1.0
      {out_x, out_y} = zoomed_out.pan
      assert_in_delta out_x, -100.0, 0.001
      assert_in_delta out_y, -80.0, 0.001
    end

    # The regression this anchor shape exists to prevent: every value in the
    # anchor is zoom/pan-independent, so wheel events queued behind an
    # unapplied zoom each anchor against current state rather than one stale
    # origin. Two half-steps must therefore equal one whole step.
    test "successive steps compose - no stale-origin jump on a wheel burst" do
      state = %SceneState{zoom: 1.0, pan: {0, 0}}
      {cx, _cy, bw, _bh, vw, _vh} = @overflow

      stepwise =
        state
        |> SceneState.zoom_at(0.5, @overflow)
        |> SceneState.zoom_at(0.5, @overflow)

      assert_in_delta stepwise.zoom, 2.0, 0.0001
      assert_in_delta anchored_x(state, stepwise, cx, bw, vw), cx, 0.001
    end

    test "an axis that still fits after the step stays centered, not anchored" do
      # base 400 in a 1000 viewport: still fits at zoom 2.0 (800 wide).
      anchor = {900, 900, 400.0, 400.0, 1000.0, 1000.0}
      state = %SceneState{zoom: 1.0, pan: {0, 0}}

      zoomed = SceneState.zoom_at(state, 1.0, anchor)

      assert zoomed.zoom == 2.0
      # Centering wins by design: rendered_origin ignores pan while fitting.
      assert SceneState.rendered_origin(elem(zoomed.pan, 0), 800.0, 1000.0) == 100
    end

    test "clamping at the maximum leaves the map where it is" do
      state = %SceneState{zoom: 3.0, pan: {-100, -200}}

      zoomed = SceneState.zoom_at(state, 1.0, @overflow)

      assert zoomed.zoom == 3.0
      {px, py} = zoomed.pan
      assert_in_delta px, -100.0, 0.001
      assert_in_delta py, -200.0, 0.001
    end

    test "clamping at the minimum leaves the map where it is" do
      state = %SceneState{zoom: 0.5, pan: {-10, -20}}
      # base sized so both axes still overflow at 0.5 zoom
      anchor = {400, 300, 4000.0, 3000.0, 1000.0, 700.0}

      zoomed = SceneState.zoom_at(state, -1.0, anchor)

      assert zoomed.zoom == 0.5
      {px, py} = zoomed.pan
      assert_in_delta px, -10.0, 0.001
      assert_in_delta py, -20.0, 0.001
    end

    test "zoom is clamped to the bounds when a step overshoots" do
      assert SceneState.zoom_at(%SceneState{zoom: 2.9}, 1.0, @overflow).zoom == 3.0
      assert SceneState.zoom_at(%SceneState{zoom: 0.6}, -1.0, @overflow).zoom == 0.5
    end
  end

  describe "run_event/2 - {:map_zoom, exponent, anchor}" do
    test "a positive exponent zooms in" do
      state = %SceneState{zoom: 1.0, pan: {0, 0}}

      assert SceneState.run_event(state, {:map_zoom, 1.0, @overflow}).zoom == 2.0
    end

    test "a negative exponent zooms out" do
      state = %SceneState{zoom: 2.0, pan: {0, 0}}

      assert SceneState.run_event(state, {:map_zoom, -1.0, @overflow}).zoom == 1.0
    end
  end
end
