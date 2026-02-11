//
//  ProBadge.swift
//  Eclat
//
//  Custom Pro badge icon
//

import SwiftUI

struct ProBadgeIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.5*width, y: 0.20833*height))
        path.addCurve(to: CGPoint(x: 0.17783*width, y: 0.25014*height), control1: CGPoint(x: 0.39608*width, y: 0.20833*height), control2: CGPoint(x: 0.27436*width, y: 0.21323*height))
        path.addCurve(to: CGPoint(x: 0.05115*width, y: 0.33861*height), control1: CGPoint(x: 0.12883*width, y: 0.26888*height), control2: CGPoint(x: 0.08385*width, y: 0.29674*height))
        path.addCurve(to: CGPoint(x: 0, y: 0.5*height), control1: CGPoint(x: 0.01803*width, y: 0.38102*height), control2: CGPoint(x: 0, y: 0.43463*height))
        path.addCurve(to: CGPoint(x: 0.05737*width, y: 0.69627*height), control1: CGPoint(x: 0, y: 0.56866*height), control2: CGPoint(x: 0.01705*width, y: 0.64045*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: 0.79167*height), control1: CGPoint(x: 0.09885*width, y: 0.7537*height), control2: CGPoint(x: 0.16335*width, y: 0.79167*height))
        path.addCurve(to: CGPoint(x: 0.35543*width, y: 0.76729*height), control1: CGPoint(x: 0.29287*width, y: 0.79167*height), control2: CGPoint(x: 0.32696*width, y: 0.78237*height))
        path.addCurve(to: CGPoint(x: 0.42009*width, y: 0.71696*height), control1: CGPoint(x: 0.38329*width, y: 0.75254*height), control2: CGPoint(x: 0.40382*width, y: 0.73323*height))
        path.addLine(to: CGPoint(x: 0.4259*width, y: 0.71114*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.66667*height), control1: CGPoint(x: 0.45645*width, y: 0.68048*height), control2: CGPoint(x: 0.47022*width, y: 0.66667*height))
        path.addCurve(to: CGPoint(x: 0.5741*width, y: 0.71114*height), control1: CGPoint(x: 0.52978*width, y: 0.66667*height), control2: CGPoint(x: 0.54355*width, y: 0.68048*height))
        path.addLine(to: CGPoint(x: 0.57991*width, y: 0.71696*height))
        path.addCurve(to: CGPoint(x: 0.64457*width, y: 0.76729*height), control1: CGPoint(x: 0.59618*width, y: 0.73323*height), control2: CGPoint(x: 0.6167*width, y: 0.75254*height))
        path.addCurve(to: CGPoint(x: 0.75*width, y: 0.79167*height), control1: CGPoint(x: 0.67304*width, y: 0.78237*height), control2: CGPoint(x: 0.70713*width, y: 0.79167*height))
        path.addCurve(to: CGPoint(x: 0.94272*width, y: 0.69515*height), control1: CGPoint(x: 0.83698*width, y: 0.79167*height), control2: CGPoint(x: 0.90141*width, y: 0.75275*height))
        path.addCurve(to: CGPoint(x: width, y: 0.5*height), control1: CGPoint(x: 0.98289*width, y: 0.63912*height), control2: CGPoint(x: width, y: 0.56745*height))
        path.addCurve(to: CGPoint(x: 0.94885*width, y: 0.33861*height), control1: CGPoint(x: width, y: 0.43463*height), control2: CGPoint(x: 0.98197*width, y: 0.38102*height))
        path.addCurve(to: CGPoint(x: 0.82217*width, y: 0.25014*height), control1: CGPoint(x: 0.91615*width, y: 0.29674*height), control2: CGPoint(x: 0.87117*width, y: 0.26888*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.20833*height), control1: CGPoint(x: 0.72564*width, y: 0.21323*height), control2: CGPoint(x: 0.60392*width, y: 0.20833*height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pro Badge View
struct ProBadge: View {
    var size: CGFloat = 12
    var color: Color = .white
    
    var body: some View {
        ProBadgeIcon()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Delete Icon Shape
struct DeleteIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.4419*width, y: 0.14839*height))
        path.addCurve(to: CGPoint(x: 0.28464*width, y: 0.1308*height), control1: CGPoint(x: 0.3902*width, y: 0.12454*height), control2: CGPoint(x: 0.33571*width, y: 0.11942*height))
        path.addCurve(to: CGPoint(x: 0.10373*width, y: 0.28762*height), control1: CGPoint(x: 0.2043*width, y: 0.14872*height), control2: CGPoint(x: 0.13619*width, y: 0.2067*height))
        path.addCurve(to: CGPoint(x: 0.47965*width, y: 0.89052*height), control1: CGPoint(x: 0.03689*width, y: 0.45429*height), control2: CGPoint(x: 0.12432*width, y: 0.69136*height))
        path.addCurve(to: CGPoint(x: 0.52039*width, y: 0.89052*height), control1: CGPoint(x: 0.4923*width, y: 0.89762*height), control2: CGPoint(x: 0.50774*width, y: 0.89762*height))
        path.addCurve(to: CGPoint(x: 0.8963*width, y: 0.28762*height), control1: CGPoint(x: 0.87572*width, y: 0.69136*height), control2: CGPoint(x: 0.96314*width, y: 0.45428*height))
        path.addCurve(to: CGPoint(x: 0.7154*width, y: 0.1308*height), control1: CGPoint(x: 0.86385*width, y: 0.2067*height), control2: CGPoint(x: 0.79574*width, y: 0.14872*height))
        path.addCurve(to: CGPoint(x: 0.54041*width, y: 0.15737*height), control1: CGPoint(x: 0.65845*width, y: 0.11811*height), control2: CGPoint(x: 0.59726*width, y: 0.12593*height))
        path.addCurve(to: CGPoint(x: 0.45875*width, y: 0.35815*height), control1: CGPoint(x: 0.49531*width, y: 0.20593*height), control2: CGPoint(x: 0.46274*width, y: 0.27694*height))
        path.addLine(to: CGPoint(x: 0.58934*width, y: 0.48875*height))
        path.addLine(to: CGPoint(x: 0.53953*width, y: 0.63818*height))
        path.addCurve(to: CGPoint(x: 0.48683*width, y: 0.66453*height), control1: CGPoint(x: 0.53225*width, y: 0.66*height), control2: CGPoint(x: 0.50865*width, y: 0.6718*height))
        path.addCurve(to: CGPoint(x: 0.46047*width, y: 0.61182*height), control1: CGPoint(x: 0.46499*width, y: 0.65725*height), control2: CGPoint(x: 0.4532*width, y: 0.63365*height))
        path.addLine(to: CGPoint(x: 0.494*width, y: 0.51125*height))
        path.addLine(to: CGPoint(x: 0.375*width, y: 0.39226*height))
        path.addLine(to: CGPoint(x: 0.375*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.4419*width, y: 0.14839*height), control1: CGPoint(x: 0.375*width, y: 0.29088*height), control2: CGPoint(x: 0.40021*width, y: 0.2117*height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Delete Badge View
struct DeleteBadge: View {
    var size: CGFloat = 12
    var color: Color = .red
    
    var body: some View {
        DeleteIcon()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Terms Icon Shape (Document with lines)
struct TermsIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.14583*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.22917*width, y: 0.5*height))
        path.move(to: CGPoint(x: 0.41667*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.5*width, y: 0.5*height))
        path.move(to: CGPoint(x: 0.41667*width, y: 0.33333*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.33333*height))
        path.move(to: CGPoint(x: 0.14583*width, y: 0.33333*height))
        path.addLine(to: CGPoint(x: 0.22917*width, y: 0.33333*height))
        path.move(to: CGPoint(x: 0.14583*width, y: 0.66667*height))
        path.addLine(to: CGPoint(x: 0.22917*width, y: 0.66667*height))
        path.move(to: CGPoint(x: 0.3125*width, y: 0.85417*height))
        path.addLine(to: CGPoint(x: 0.6875*width, y: 0.85417*height))
        path.addCurve(to: CGPoint(x: 0.8125*width, y: 0.72917*height), control1: CGPoint(x: 0.75654*width, y: 0.85417*height), control2: CGPoint(x: 0.8125*width, y: 0.7982*height))
        path.addLine(to: CGPoint(x: 0.8125*width, y: 0.27083*height))
        path.addCurve(to: CGPoint(x: 0.6875*width, y: 0.14583*height), control1: CGPoint(x: 0.8125*width, y: 0.2018*height), control2: CGPoint(x: 0.75654*width, y: 0.14583*height))
        path.addLine(to: CGPoint(x: 0.3125*width, y: 0.14583*height))
        path.addCurve(to: CGPoint(x: 0.1875*width, y: 0.27083*height), control1: CGPoint(x: 0.24346*width, y: 0.14583*height), control2: CGPoint(x: 0.1875*width, y: 0.2018*height))
        path.addLine(to: CGPoint(x: 0.1875*width, y: 0.72917*height))
        path.addCurve(to: CGPoint(x: 0.3125*width, y: 0.85417*height), control1: CGPoint(x: 0.1875*width, y: 0.7982*height), control2: CGPoint(x: 0.24346*width, y: 0.85417*height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Terms Badge View
struct TermsBadge: View {
    var size: CGFloat = 12
    var color: Color = .white
    
    var body: some View {
        TermsIcon()
            .stroke(color, lineWidth: 1.5)
            .frame(width: size, height: size)
    }
}

// MARK: - Rate Icon Shape (Review/Star icon)
struct RateIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.25*width, y: 0.22917*height))
        path.addCurve(to: CGPoint(x: 0.22917*width, y: 0.20833*height), control1: CGPoint(x: 0.25*width, y: 0.21766*height), control2: CGPoint(x: 0.24067*width, y: 0.20833*height))
        path.addCurve(to: CGPoint(x: 0.20833*width, y: 0.22917*height), control1: CGPoint(x: 0.21766*width, y: 0.20833*height), control2: CGPoint(x: 0.20833*width, y: 0.21766*height))
        path.addCurve(to: CGPoint(x: 0.18449*width, y: 0.30949*height), control1: CGPoint(x: 0.20833*width, y: 0.27003*height), control2: CGPoint(x: 0.19928*width, y: 0.29469*height))
        path.addCurve(to: CGPoint(x: 0.10417*width, y: 0.33333*height), control1: CGPoint(x: 0.16969*width, y: 0.32428*height), control2: CGPoint(x: 0.14503*width, y: 0.33333*height))
        path.addCurve(to: CGPoint(x: 0.08333*width, y: 0.35417*height), control1: CGPoint(x: 0.09266*width, y: 0.33333*height), control2: CGPoint(x: 0.08333*width, y: 0.34266*height))
        path.addCurve(to: CGPoint(x: 0.10417*width, y: 0.375*height), control1: CGPoint(x: 0.08333*width, y: 0.36567*height), control2: CGPoint(x: 0.09266*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.18449*width, y: 0.39885*height), control1: CGPoint(x: 0.14503*width, y: 0.375*height), control2: CGPoint(x: 0.16969*width, y: 0.38405*height))
        path.addCurve(to: CGPoint(x: 0.20833*width, y: 0.47917*height), control1: CGPoint(x: 0.19928*width, y: 0.41364*height), control2: CGPoint(x: 0.20833*width, y: 0.43831*height))
        path.addCurve(to: CGPoint(x: 0.22917*width, y: 0.5*height), control1: CGPoint(x: 0.20833*width, y: 0.49067*height), control2: CGPoint(x: 0.21766*width, y: 0.5*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: 0.47917*height), control1: CGPoint(x: 0.24067*width, y: 0.5*height), control2: CGPoint(x: 0.25*width, y: 0.49067*height))
        path.addCurve(to: CGPoint(x: 0.27385*width, y: 0.39885*height), control1: CGPoint(x: 0.25*width, y: 0.43831*height), control2: CGPoint(x: 0.25905*width, y: 0.41364*height))
        path.addCurve(to: CGPoint(x: 0.35417*width, y: 0.375*height), control1: CGPoint(x: 0.28864*width, y: 0.38405*height), control2: CGPoint(x: 0.31331*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.375*width, y: 0.35417*height), control1: CGPoint(x: 0.36567*width, y: 0.375*height), control2: CGPoint(x: 0.375*width, y: 0.36567*height))
        path.addCurve(to: CGPoint(x: 0.35417*width, y: 0.33333*height), control1: CGPoint(x: 0.375*width, y: 0.34266*height), control2: CGPoint(x: 0.36567*width, y: 0.33333*height))
        path.addCurve(to: CGPoint(x: 0.27385*width, y: 0.30949*height), control1: CGPoint(x: 0.31331*width, y: 0.33333*height), control2: CGPoint(x: 0.28864*width, y: 0.32428*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: 0.22917*height), control1: CGPoint(x: 0.25905*width, y: 0.29469*height), control2: CGPoint(x: 0.25*width, y: 0.27003*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.45833*width, y: 0.0625*height))
        path.addCurve(to: CGPoint(x: 0.4375*width, y: 0.04167*height), control1: CGPoint(x: 0.45833*width, y: 0.05099*height), control2: CGPoint(x: 0.449*width, y: 0.04167*height))
        path.addCurve(to: CGPoint(x: 0.41667*width, y: 0.0625*height), control1: CGPoint(x: 0.426*width, y: 0.04167*height), control2: CGPoint(x: 0.41667*width, y: 0.05099*height))
        path.addCurve(to: CGPoint(x: 0.4028*width, y: 0.11114*height), control1: CGPoint(x: 0.41667*width, y: 0.08889*height), control2: CGPoint(x: 0.4108*width, y: 0.10314*height))
        path.addCurve(to: CGPoint(x: 0.35417*width, y: 0.125*height), control1: CGPoint(x: 0.39481*width, y: 0.11913*height), control2: CGPoint(x: 0.38056*width, y: 0.125*height))
        path.addCurve(to: CGPoint(x: 0.33333*width, y: 0.14583*height), control1: CGPoint(x: 0.34266*width, y: 0.125*height), control2: CGPoint(x: 0.33333*width, y: 0.13433*height))
        path.addCurve(to: CGPoint(x: 0.35417*width, y: 0.16667*height), control1: CGPoint(x: 0.33333*width, y: 0.15734*height), control2: CGPoint(x: 0.34266*width, y: 0.16667*height))
        path.addCurve(to: CGPoint(x: 0.4028*width, y: 0.18053*height), control1: CGPoint(x: 0.38056*width, y: 0.16667*height), control2: CGPoint(x: 0.39481*width, y: 0.17253*height))
        path.addCurve(to: CGPoint(x: 0.41667*width, y: 0.22917*height), control1: CGPoint(x: 0.4108*width, y: 0.18853*height), control2: CGPoint(x: 0.41667*width, y: 0.20277*height))
        path.addCurve(to: CGPoint(x: 0.4375*width, y: 0.25*height), control1: CGPoint(x: 0.41667*width, y: 0.24067*height), control2: CGPoint(x: 0.426*width, y: 0.25*height))
        path.addCurve(to: CGPoint(x: 0.45833*width, y: 0.22917*height), control1: CGPoint(x: 0.449*width, y: 0.25*height), control2: CGPoint(x: 0.45833*width, y: 0.24067*height))
        path.addCurve(to: CGPoint(x: 0.4722*width, y: 0.18053*height), control1: CGPoint(x: 0.45833*width, y: 0.20277*height), control2: CGPoint(x: 0.4642*width, y: 0.18853*height))
        path.addCurve(to: CGPoint(x: 0.52083*width, y: 0.16667*height), control1: CGPoint(x: 0.48019*width, y: 0.17253*height), control2: CGPoint(x: 0.49444*width, y: 0.16667*height))
        path.addCurve(to: CGPoint(x: 0.54167*width, y: 0.14583*height), control1: CGPoint(x: 0.53234*width, y: 0.16667*height), control2: CGPoint(x: 0.54167*width, y: 0.15734*height))
        path.addCurve(to: CGPoint(x: 0.52083*width, y: 0.125*height), control1: CGPoint(x: 0.54167*width, y: 0.13433*height), control2: CGPoint(x: 0.53234*width, y: 0.125*height))
        path.addCurve(to: CGPoint(x: 0.4722*width, y: 0.11114*height), control1: CGPoint(x: 0.49444*width, y: 0.125*height), control2: CGPoint(x: 0.48019*width, y: 0.11913*height))
        path.addCurve(to: CGPoint(x: 0.45833*width, y: 0.0625*height), control1: CGPoint(x: 0.4642*width, y: 0.10314*height), control2: CGPoint(x: 0.45833*width, y: 0.08889*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.83333*width, y: 0.625*height))
        path.addCurve(to: CGPoint(x: 0.54167*width, y: 0.91667*height), control1: CGPoint(x: 0.63079*width, y: 0.625*height), control2: CGPoint(x: 0.54167*width, y: 0.71412*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: 0.625*height), control1: CGPoint(x: 0.54167*width, y: 0.71412*height), control2: CGPoint(x: 0.45255*width, y: 0.625*height))
        path.addCurve(to: CGPoint(x: 0.54167*width, y: 0.33333*height), control1: CGPoint(x: 0.45255*width, y: 0.625*height), control2: CGPoint(x: 0.54167*width, y: 0.53588*height))
        path.addCurve(to: CGPoint(x: 0.83333*width, y: 0.625*height), control1: CGPoint(x: 0.54167*width, y: 0.53588*height), control2: CGPoint(x: 0.63079*width, y: 0.625*height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Rate Badge View
struct RateBadge: View {
    var size: CGFloat = 12
    var color: Color = .white
    
    var body: some View {
        RateIcon()
            .fill(color)
            .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProBadge(size: 20, color: .yellow)
        ProBadge(size: 30, color: .white)
        ProBadge(size: 40, color: .orange)
        DeleteBadge(size: 20, color: .red)
        DeleteBadge(size: 30, color: .white)
        TermsBadge(size: 24, color: .white)
        TermsBadge(size: 30, color: .blue)
        RateBadge(size: 24, color: .yellow)
    }
    .padding()
    .background(Color.black)
}

// MARK: - Privacy Icon Shape (Lock)
struct PrivacyIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.20833*width, y: 0.54167*height))
        path.addCurve(to: CGPoint(x: 0.33333*width, y: 0.41667*height), control1: CGPoint(x: 0.20833*width, y: 0.47263*height), control2: CGPoint(x: 0.2643*width, y: 0.41667*height))
        path.addLine(to: CGPoint(x: 0.66667*width, y: 0.41667*height))
        path.addCurve(to: CGPoint(x: 0.79167*width, y: 0.54167*height), control1: CGPoint(x: 0.7357*width, y: 0.41667*height), control2: CGPoint(x: 0.79167*width, y: 0.47263*height))
        path.addLine(to: CGPoint(x: 0.79167*width, y: 0.75*height))
        path.addCurve(to: CGPoint(x: 0.66667*width, y: 0.875*height), control1: CGPoint(x: 0.79167*width, y: 0.81904*height), control2: CGPoint(x: 0.7357*width, y: 0.875*height))
        path.addLine(to: CGPoint(x: 0.33333*width, y: 0.875*height))
        path.addCurve(to: CGPoint(x: 0.20833*width, y: 0.75*height), control1: CGPoint(x: 0.2643*width, y: 0.875*height), control2: CGPoint(x: 0.20833*width, y: 0.81904*height))
        path.addLine(to: CGPoint(x: 0.20833*width, y: 0.54167*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.66667*width, y: 0.39583*height))
        path.addLine(to: CGPoint(x: 0.66667*width, y: 0.29167*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.125*height), control1: CGPoint(x: 0.66667*width, y: 0.19962*height), control2: CGPoint(x: 0.59205*width, y: 0.125*height))
        path.addCurve(to: CGPoint(x: 0.33333*width, y: 0.29167*height), control1: CGPoint(x: 0.40795*width, y: 0.125*height), control2: CGPoint(x: 0.33333*width, y: 0.19962*height))
        path.addLine(to: CGPoint(x: 0.33333*width, y: 0.39583*height))
        path.move(to: CGPoint(x: 0.5*width, y: 0.58333*height))
        path.addLine(to: CGPoint(x: 0.5*width, y: 0.70833*height))
        return path
    }
}

// MARK: - Privacy Badge View
struct PrivacyBadge: View {
    var size: CGFloat = 12
    var color: Color = .white
    
    var body: some View {
        PrivacyIcon()
            .stroke(color, lineWidth: 1.5)
            .frame(width: size, height: size)
    }
}

// MARK: - Logout Icon Shape
struct LogoutIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.46875*width, y: 0.83333*height))
        path.addLine(to: CGPoint(x: 0.29167*width, y: 0.83333*height))
        path.addCurve(to: CGPoint(x: 0.16667*width, y: 0.70833*height), control1: CGPoint(x: 0.22263*width, y: 0.83333*height), control2: CGPoint(x: 0.16667*width, y: 0.77737*height))
        path.addLine(to: CGPoint(x: 0.16667*width, y: 0.29167*height))
        path.addCurve(to: CGPoint(x: 0.29167*width, y: 0.16667*height), control1: CGPoint(x: 0.16667*width, y: 0.22263*height), control2: CGPoint(x: 0.22263*width, y: 0.16667*height))
        path.addLine(to: CGPoint(x: 0.46875*width, y: 0.16667*height))
        path.move(to: CGPoint(x: 0.83333*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.36458*width, y: 0.5*height))
        path.move(to: CGPoint(x: 0.83333*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.64583*width, y: 0.6875*height))
        path.move(to: CGPoint(x: 0.83333*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.64583*width, y: 0.3125*height))
        return path
    }
}

// MARK: - Logout Badge View
struct LogoutBadge: View {
    var size: CGFloat = 12
    var color: Color = .red
    
    var body: some View {
        LogoutIcon()
            .stroke(color, lineWidth: 1.5)
            .frame(width: size, height: size)
    }
}

// MARK: - Feedback Icon Shape (Message/Mail with speedometer)
struct FeedbackIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.54167*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.5*width, y: 0.5*height))
        path.addCurve(to: CGPoint(x: 0.54167*width, y: 0.54167*height), control1: CGPoint(x: 0.5*width, y: 0.52301*height), control2: CGPoint(x: 0.51865*width, y: 0.54167*height))
        path.addLine(to: CGPoint(x: 0.54167*width, y: 0.5*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.41667*width, y: 0.5625*height))
        path.addLine(to: CGPoint(x: 0.39803*width, y: 0.59977*height))
        path.addCurve(to: CGPoint(x: 0.43857*width, y: 0.59794*height), control1: CGPoint(x: 0.41095*width, y: 0.60623*height), control2: CGPoint(x: 0.42629*width, y: 0.60554*height))
        path.addCurve(to: CGPoint(x: 0.45833*width, y: 0.5625*height), control1: CGPoint(x: 0.45085*width, y: 0.59035*height), control2: CGPoint(x: 0.45833*width, y: 0.57694*height))
        path.addLine(to: CGPoint(x: 0.41667*width, y: 0.5625*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.41434*width, y: 0.56134*height))
        path.addLine(to: CGPoint(x: 0.3957*width, y: 0.5986*height))
        path.addLine(to: CGPoint(x: 0.3957*width, y: 0.5986*height))
        path.addLine(to: CGPoint(x: 0.41434*width, y: 0.56134*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.2997*width, y: 0.60492*height))
        path.addLine(to: CGPoint(x: 0.26101*width, y: 0.58945*height))
        path.addLine(to: CGPoint(x: 0.26101*width, y: 0.58945*height))
        path.addLine(to: CGPoint(x: 0.2997*width, y: 0.60492*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.29167*width, y: 0.625*height))
        path.addLine(to: CGPoint(x: 0.25298*width, y: 0.60952*height))
        path.addCurve(to: CGPoint(x: 0.257*width, y: 0.64811*height), control1: CGPoint(x: 0.24788*width, y: 0.62227*height), control2: CGPoint(x: 0.24939*width, y: 0.6367*height))
        path.addLine(to: CGPoint(x: 0.29167*width, y: 0.625*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.40886*width, y: 0.80078*height))
        path.addLine(to: CGPoint(x: 0.44353*width, y: 0.77767*height))
        path.addLine(to: CGPoint(x: 0.40886*width, y: 0.80078*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.68462*width, y: 0.34023*height))
        path.addCurve(to: CGPoint(x: 0.7326*width, y: 0.37443*height), control1: CGPoint(x: 0.68843*width, y: 0.36292*height), control2: CGPoint(x: 0.70991*width, y: 0.37823*height))
        path.addCurve(to: CGPoint(x: 0.7668*width, y: 0.32644*height), control1: CGPoint(x: 0.7553*width, y: 0.37062*height), control2: CGPoint(x: 0.77061*width, y: 0.34913*height))
        path.addLine(to: CGPoint(x: 0.68462*width, y: 0.34023*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.19153*width, y: 0.42356*height))
        path.addCurve(to: CGPoint(x: 0.23952*width, y: 0.45776*height), control1: CGPoint(x: 0.19534*width, y: 0.44625*height), control2: CGPoint(x: 0.21682*width, y: 0.46157*height))
        path.addCurve(to: CGPoint(x: 0.27372*width, y: 0.40977*height), control1: CGPoint(x: 0.26221*width, y: 0.45395*height), control2: CGPoint(x: 0.27752*width, y: 0.43247*height))
        path.addLine(to: CGPoint(x: 0.19153*width, y: 0.42356*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.58333*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.375*height))
        path.addLine(to: CGPoint(x: 0.5*width, y: 0.375*height))
        path.addLine(to: CGPoint(x: 0.5*width, y: 0.5*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.5*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.375*width, y: 0.375*height))
        path.addLine(to: CGPoint(x: 0.375*width, y: 0.5625*height))
        path.addLine(to: CGPoint(x: 0.45833*width, y: 0.5625*height))
        path.addLine(to: CGPoint(x: 0.45833*width, y: 0.375*height))
        path.addLine(to: CGPoint(x: 0.375*width, y: 0.375*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4353*width, y: 0.52523*height))
        path.addLine(to: CGPoint(x: 0.43297*width, y: 0.52407*height))
        path.addLine(to: CGPoint(x: 0.3957*width, y: 0.5986*height))
        path.addLine(to: CGPoint(x: 0.39803*width, y: 0.59977*height))
        path.addLine(to: CGPoint(x: 0.4353*width, y: 0.52523*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.26101*width, y: 0.58945*height))
        path.addLine(to: CGPoint(x: 0.25298*width, y: 0.60952*height))
        path.addLine(to: CGPoint(x: 0.33035*width, y: 0.64048*height))
        path.addLine(to: CGPoint(x: 0.33838*width, y: 0.6204*height))
        path.addLine(to: CGPoint(x: 0.26101*width, y: 0.58945*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.257*width, y: 0.64811*height))
        path.addLine(to: CGPoint(x: 0.37419*width, y: 0.8239*height))
        path.addLine(to: CGPoint(x: 0.44353*width, y: 0.77767*height))
        path.addLine(to: CGPoint(x: 0.32634*width, y: 0.60189*height))
        path.addLine(to: CGPoint(x: 0.257*width, y: 0.64811*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.54753*width, y: 0.91667*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.91667*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.83333*height))
        path.addLine(to: CGPoint(x: 0.54753*width, y: 0.83333*height))
        path.addLine(to: CGPoint(x: 0.54753*width, y: 0.91667*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.83333*width, y: 0.66667*height))
        path.addLine(to: CGPoint(x: 0.83333*width, y: 0.625*height))
        path.addLine(to: CGPoint(x: 0.75*width, y: 0.625*height))
        path.addLine(to: CGPoint(x: 0.75*width, y: 0.66667*height))
        path.addLine(to: CGPoint(x: 0.83333*width, y: 0.66667*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.66667*width, y: 0.45833*height))
        path.addLine(to: CGPoint(x: 0.54167*width, y: 0.45833*height))
        path.addLine(to: CGPoint(x: 0.54167*width, y: 0.54167*height))
        path.addLine(to: CGPoint(x: 0.66667*width, y: 0.54167*height))
        path.addLine(to: CGPoint(x: 0.66667*width, y: 0.45833*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.83333*width, y: 0.625*height))
        path.addCurve(to: CGPoint(x: 0.66667*width, y: 0.45833*height), control1: CGPoint(x: 0.83333*width, y: 0.53295*height), control2: CGPoint(x: 0.75871*width, y: 0.45833*height))
        path.addLine(to: CGPoint(x: 0.66667*width, y: 0.54167*height))
        path.addCurve(to: CGPoint(x: 0.75*width, y: 0.625*height), control1: CGPoint(x: 0.71269*width, y: 0.54167*height), control2: CGPoint(x: 0.75*width, y: 0.57898*height))
        path.addLine(to: CGPoint(x: 0.83333*width, y: 0.625*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.43297*width, y: 0.52407*height))
        path.addCurve(to: CGPoint(x: 0.26101*width, y: 0.58945*height), control1: CGPoint(x: 0.36756*width, y: 0.49136*height), control2: CGPoint(x: 0.28817*width, y: 0.52155*height))
        path.addLine(to: CGPoint(x: 0.33838*width, y: 0.6204*height))
        path.addCurve(to: CGPoint(x: 0.3957*width, y: 0.5986*height), control1: CGPoint(x: 0.34744*width, y: 0.59776*height), control2: CGPoint(x: 0.3739*width, y: 0.5877*height))
        path.addLine(to: CGPoint(x: 0.43297*width, y: 0.52407*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.58333*width, y: 0.91667*height))
        path.addCurve(to: CGPoint(x: 0.83333*width, y: 0.66667*height), control1: CGPoint(x: 0.7214*width, y: 0.91667*height), control2: CGPoint(x: 0.83333*width, y: 0.80474*height))
        path.addLine(to: CGPoint(x: 0.75*width, y: 0.66667*height))
        path.addCurve(to: CGPoint(x: 0.58333*width, y: 0.83333*height), control1: CGPoint(x: 0.75*width, y: 0.75871*height), control2: CGPoint(x: 0.67538*width, y: 0.83333*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.91667*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.47917*width, y: 0.27083*height))
        path.addCurve(to: CGPoint(x: 0.375*width, y: 0.375*height), control1: CGPoint(x: 0.42164*width, y: 0.27083*height), control2: CGPoint(x: 0.375*width, y: 0.31747*height))
        path.addLine(to: CGPoint(x: 0.45833*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.47917*width, y: 0.35417*height), control1: CGPoint(x: 0.45833*width, y: 0.36349*height), control2: CGPoint(x: 0.46766*width, y: 0.35417*height))
        path.addLine(to: CGPoint(x: 0.47917*width, y: 0.27083*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.37419*width, y: 0.8239*height))
        path.addCurve(to: CGPoint(x: 0.54753*width, y: 0.91667*height), control1: CGPoint(x: 0.41283*width, y: 0.88185*height), control2: CGPoint(x: 0.47787*width, y: 0.91667*height))
        path.addLine(to: CGPoint(x: 0.54753*width, y: 0.83333*height))
        path.addCurve(to: CGPoint(x: 0.44353*width, y: 0.77767*height), control1: CGPoint(x: 0.50574*width, y: 0.83333*height), control2: CGPoint(x: 0.46671*width, y: 0.81245*height))
        path.addLine(to: CGPoint(x: 0.37419*width, y: 0.8239*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.58333*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.47917*width, y: 0.27083*height), control1: CGPoint(x: 0.58333*width, y: 0.31747*height), control2: CGPoint(x: 0.5367*width, y: 0.27083*height))
        path.addLine(to: CGPoint(x: 0.47917*width, y: 0.35417*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.375*height), control1: CGPoint(x: 0.49067*width, y: 0.35417*height), control2: CGPoint(x: 0.5*width, y: 0.36349*height))
        path.addLine(to: CGPoint(x: 0.58333*width, y: 0.375*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.27083*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.47917*width, y: 0.16667*height), control1: CGPoint(x: 0.27083*width, y: 0.25994*height), control2: CGPoint(x: 0.36411*width, y: 0.16667*height))
        path.addLine(to: CGPoint(x: 0.47917*width, y: 0.08333*height))
        path.addCurve(to: CGPoint(x: 0.1875*width, y: 0.375*height), control1: CGPoint(x: 0.31808*width, y: 0.08333*height), control2: CGPoint(x: 0.1875*width, y: 0.21392*height))
        path.addLine(to: CGPoint(x: 0.27083*width, y: 0.375*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.47917*width, y: 0.16667*height))
        path.addCurve(to: CGPoint(x: 0.68462*width, y: 0.34023*height), control1: CGPoint(x: 0.58235*width, y: 0.16667*height), control2: CGPoint(x: 0.66809*width, y: 0.24173*height))
        path.addLine(to: CGPoint(x: 0.7668*width, y: 0.32644*height))
        path.addCurve(to: CGPoint(x: 0.47917*width, y: 0.08333*height), control1: CGPoint(x: 0.74365*width, y: 0.18846*height), control2: CGPoint(x: 0.62373*width, y: 0.08333*height))
        path.addLine(to: CGPoint(x: 0.47917*width, y: 0.16667*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.27372*width, y: 0.40977*height))
        path.addCurve(to: CGPoint(x: 0.27083*width, y: 0.375*height), control1: CGPoint(x: 0.27182*width, y: 0.39849*height), control2: CGPoint(x: 0.27083*width, y: 0.38688*height))
        path.addLine(to: CGPoint(x: 0.1875*width, y: 0.375*height))
        path.addCurve(to: CGPoint(x: 0.19153*width, y: 0.42356*height), control1: CGPoint(x: 0.1875*width, y: 0.39152*height), control2: CGPoint(x: 0.18888*width, y: 0.40774*height))
        path.addLine(to: CGPoint(x: 0.27372*width, y: 0.40977*height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Feedback Badge View
struct FeedbackBadge: View {
    var size: CGFloat = 12
    var color: Color = .white
    
    var body: some View {
        FeedbackIcon()
            .fill(color)
            .frame(width: size, height: size)
    }
}
