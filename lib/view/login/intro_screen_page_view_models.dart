import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lanis/generated/l10n.dart';

List<PageViewModel> intoScreenPageViewModels(BuildContext context) => [
      PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_welcome_re_h3d9.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introWelcomeTitle,
        body: AppLocalizations.of(context).introWelcome,
      ),
      PageViewModel(
        image: SvgPicture.asset(
            "assets/undraw/undraw_engineering_team_a7n2.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introForStudentsByStudentsTitle,
        body: AppLocalizations.of(context).introForStudentsByStudents,
      ),
      PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_editable_re_4l94.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introCustomizeTitle,
        body: AppLocalizations.of(context).introCustomize,
      ),
      PageViewModel(
        image: SvgPicture.asset(
            "assets/undraw/undraw_building_blocks_re_5ahy.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introSchoolPortalTitle,
        body: AppLocalizations.of(context).introSchoolPortal,
      ),
      PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_bug_fixing_oc-7-a.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introAnalyticsTitle,
        body: AppLocalizations.of(context).introAnalytics,
      ),
      PageViewModel(
        image: SvgPicture.asset(
            "assets/undraw/undraw_access_account_re_8spm.svg",
            height: 175.0),
        title: AppLocalizations.of(context).introHaveFunTitle,
        body: AppLocalizations.of(context).introHaveFun,
      ),
    ];
