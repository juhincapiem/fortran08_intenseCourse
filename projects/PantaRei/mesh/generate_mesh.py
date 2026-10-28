"""
Generate a small 2D mesh for the heat2d FEM solver using gmsh.
Linear triangles (T3), MSH 2.2 ASCII format.
"""

import gmsh 

gmsh.initialize()
gmsh.model.add("unit_square")


# --- Geometry: unit square via 4 corner points ---
lc = 0.5  # target element size

p1 = gmsh.model.geo.addPoint(0.0, 0.0, 0.0, lc)
p2 = gmsh.model.geo.addPoint(1.0, 0.0, 0.0, lc)
p3 = gmsh.model.geo.addPoint(1.0, 1.0, 0.0, lc)
p4 = gmsh.model.geo.addPoint(0.0, 1.0, 0.0, lc)

# --- Boundary lies (counter-clockwise)
l_bottom = gmsh.model.geo.add_line(p1, p2)
l_right = gmsh.model.geo.add_line(p2, p3)
l_top = gmsh.model.geo.add_line(p3, p4)
l_left = gmsh.model.geo.add_line(p4, p1)

# --- Curve loop (counter-clockwise)
curve = gmsh.model.geo.addCurveLoop([l_bottom, l_right, l_top, l_left])
surface = gmsh.model.geo.addPlaneSurface([curve])

# --- Physical groups: boundary names the solver will read ---
# Dimension 1 => edges (for boundary conditions)
gmsh.model.addPhysicalGroup(1, [l_bottom, l_left, l_top], name = "cold")
gmsh.model.addPhysicalGroup(1, [l_right], name = "hot")
# Dimension 2 => the domain surface
gmsh.model.addPhysicalGroup(2, [surface], name = "Domain")


gmsh.model.geo.synchronize()

# --- Generate 2D mesh (triangles) ---
gmsh.model.mesh.generate(2)

gmsh.option.setNumber('Mesh.SurfaceFaces', 1)

# --- Force MSH 2.2 ASCII (simplest to parse in Fortran) ---
gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
gmsh.write("./unit_square.msh")

gmsh.fltk.run()

gmsh.finalize()
print("Mesh written to unit_square.msh")

