import SwiftUI

/// Mini-program artwork in `Assets.xcassets/MP`.
/// Restyle agents apply `docs/mp-assets/mapping.md`. This type does not draw a screen.
enum MPAsset {
    enum BrandLogo {
        /// `images/cy_logo_mark.png`
        static var cyLogoMark: Image { Image("images_cy_logo_mark") }
        /// `subpackageMember/images/d_cyIcon.png`
        static var dCyIcon: Image { Image("subpackagemember_images_d_cyicon") }
        /// `subpackageMember/images/d_cyIcon2.png`
        static var dCyIcon2: Image { Image("subpackagemember_images_d_cyicon2") }
        /// `images/d_logo.png`
        static var dLogo: Image { Image("images_d_logo") }
    }

    enum TabIcon {
        /// `images/icon_f01d.png`
        static var iconF01d: Image { Image("images_icon_f01d") }
        /// `images/icon_f03d.png`
        static var iconF03d: Image { Image("images_icon_f03d") }
        /// `images/icon_f04d.png`
        static var iconF04d: Image { Image("images_icon_f04d") }
        /// `images/icon_f05d.png`
        static var iconF05d: Image { Image("images_icon_f05d") }
        /// `images/icon_f1.png`
        static var iconF1: Image { Image("images_icon_f1") }
        /// `images/icon_f3.png`
        static var iconF3: Image { Image("images_icon_f3") }
        /// `images/icon_f4.png`
        static var iconF4: Image { Image("images_icon_f4") }
        /// `images/icon_f5.png`
        static var iconF5: Image { Image("images_icon_f5") }
        /// `images/icon_roam.png`
        static var iconRoam: Image { Image("images_icon_roam") }
        /// `images/icon_roam_d.png`
        static var iconRoamD: Image { Image("images_icon_roam_d") }
        /// `images/icon_tab_club.svg`
        static var iconTabClub: Image { Image("images_icon_tab_club") }
        /// `images/icon_tab_club_on.svg`
        static var iconTabClubOn: Image { Image("images_icon_tab_club_on") }
        /// `images/icon_tab_home.svg`
        static var iconTabHome: Image { Image("images_icon_tab_home") }
        /// `images/icon_tab_home_on.svg`
        static var iconTabHomeOn: Image { Image("images_icon_tab_home_on") }
        /// `images/icon_tab_marketing.svg`
        static var iconTabMarketing: Image { Image("images_icon_tab_marketing") }
        /// `images/icon_tab_marketing_on.svg`
        static var iconTabMarketingOn: Image { Image("images_icon_tab_marketing_on") }
        /// `images/icon_tab_mine.svg`
        static var iconTabMine: Image { Image("images_icon_tab_mine") }
        /// `images/icon_tab_mine_on.svg`
        static var iconTabMineOn: Image { Image("images_icon_tab_mine_on") }
        /// `images/icon_tab_relation.svg`
        static var iconTabRelation: Image { Image("images_icon_tab_relation") }
        /// `images/icon_tab_relation_on.svg`
        static var iconTabRelationOn: Image { Image("images_icon_tab_relation_on") }
        /// `images/icon_tab_roam.svg`
        static var iconTabRoam: Image { Image("images_icon_tab_roam") }
        /// `images/icon_tab_roam_on.svg`
        static var iconTabRoamOn: Image { Image("images_icon_tab_roam_on") }
        /// `images/icon_tab_template.svg`
        static var iconTabTemplate: Image { Image("images_icon_tab_template") }
        /// `images/icon_tab_template_on.svg`
        static var iconTabTemplateOn: Image { Image("images_icon_tab_template_on") }
        /// `images/icon_tab_workbench.svg`
        static var iconTabWorkbench: Image { Image("images_icon_tab_workbench") }
        /// `images/icon_tab_workbench_on.svg`
        static var iconTabWorkbenchOn: Image { Image("images_icon_tab_workbench_on") }
        /// `pages/templatedetail/images/tpl-tab-game.svg`
        static var tplTabGame: Image { Image("pages_templatedetail_images_tpl_tab_game") }
        /// `pages/templatedetail/images/tpl-tab-topic.svg`
        static var tplTabTopic: Image { Image("pages_templatedetail_images_tpl_tab_topic") }
    }

    enum FeatureIcon {
        /// `pages/merchant/images/npc-intro/alarm_clock.png`
        static var alarmClock: Image { Image("pages_merchant_images_npc_intro_alarm_clock") }
        /// `subpackageP3/images/cat/all.png`
        static var all: Image { Image("subpackagep3_images_cat_all") }
        /// `pages/templatedetail/art/cat/art.png`
        static var art: Image { Image("pages_templatedetail_art_cat_art") }
        /// `images/publish-quick/return.png`
        static var assetReturn: Image { Image("images_publish_quick_return") }
        /// `pages/merchant/images/tags/baby.svg`
        static var baby: Image { Image("pages_merchant_images_tags_baby") }
        /// `subpackageP3/images/cat/bags.png`
        static var bags: Image { Image("subpackagep3_images_cat_bags") }
        /// `pages/merchant/images/tags/bike.svg`
        static var bike: Image { Image("pages_merchant_images_tags_bike") }
        /// `pages/templatedetail/art/cat/biz.png`
        static var biz: Image { Image("pages_templatedetail_art_cat_biz") }
        /// `pages/templatedetail/art/props/blind-taste.png`
        static var blindTaste: Image { Image("pages_templatedetail_art_props_blind_taste") }
        /// `pages/templatedetail/art/props/blind-test.png`
        static var blindTest: Image { Image("pages_templatedetail_art_props_blind_test") }
        /// `pages/templatedetail/art/3d/book.png`
        static var book: Image { Image("pages_templatedetail_art_3d_book") }
        /// `pages/merchant/images/tags/book-open.svg`
        static var bookOpen: Image { Image("pages_merchant_images_tags_book_open") }
        /// `subpackageP3/images/cat/books.png`
        static var books: Image { Image("subpackagep3_images_cat_books") }
        /// `pages/templatedetail/art/props/branch-story.png`
        static var branchStory: Image { Image("pages_templatedetail_art_props_branch_story") }
        /// `pages/merchant/images/tags/brush.svg`
        static var brush: Image { Image("pages_merchant_images_tags_brush") }
        /// `pages/templatedetail/art/3d/bulb.png`
        static var bulb: Image { Image("pages_templatedetail_art_3d_bulb") }
        /// `pages/merchant/images/tags/camera.svg`
        static var camera: Image { Image("pages_merchant_images_tags_camera") }
        /// `pages/templatedetail/art/props/cat-city.png`
        static var catCity: Image { Image("pages_templatedetail_art_props_cat_city") }
        /// `pages/templatedetail/art/props/cat-indoor.png`
        static var catIndoor: Image { Image("pages_templatedetail_art_props_cat_indoor") }
        /// `pages/templatedetail/art/props/cat-life.png`
        static var catLife: Image { Image("pages_templatedetail_art_props_cat_life") }
        /// `pages/templatedetail/art/props/cat-multi.png`
        static var catMulti: Image { Image("pages_templatedetail_art_props_cat_multi") }
        /// `pages/templatedetail/art/props/cat-quick.png`
        static var catQuick: Image { Image("pages_templatedetail_art_props_cat_quick") }
        /// `pages/templatedetail/art/props/cat-scifi.png`
        static var catScifi: Image { Image("pages_templatedetail_art_props_cat_scifi") }
        /// `pages/templatedetail/art/props/cat-shop.png`
        static var catShop: Image { Image("pages_templatedetail_art_props_cat_shop") }
        /// `pages/templatedetail/art/props/cat-solo.png`
        static var catSolo: Image { Image("pages_templatedetail_art_props_cat_solo") }
        /// `pages/templatedetail/art/props/cat-team.png`
        static var catTeam: Image { Image("pages_templatedetail_art_props_cat_team") }
        /// `pages/merchant/images/tags/check.svg`
        static var check: Image { Image("pages_merchant_images_tags_check") }
        /// `pages/templatedetail/art/tab/chev.svg`
        static var chev: Image { Image("pages_templatedetail_art_tab_chev") }
        /// `images/cards/chevron.svg`
        static var chevron: Image { Image("images_cards_chevron") }
        /// `images/publish-quick/city.png`
        static var city: Image { Image("images_publish_quick_city") }
        /// `pages/templatedetail/art/props/city-camera.png`
        static var cityCamera: Image { Image("pages_templatedetail_art_props_city_camera") }
        /// `images/cards/citylink.svg`
        static var citylink: Image { Image("images_cards_citylink") }
        /// `images/cards/clock.svg`
        static var clock: Image { Image("images_cards_clock") }
        /// `pages/templatedetail/art/cat/cloth.png`
        static var cloth: Image { Image("pages_templatedetail_art_cat_cloth") }
        /// `subpackageP3/images/cat/clothing.png`
        static var clothing: Image { Image("subpackagep3_images_cat_clothing") }
        /// `pages/club/images/tags/coffee.svg`
        static var coffee: Image { Image("pages_club_images_tags_coffee") }
        /// `pages/templatedetail/art/props/coffee-personality.png`
        static var coffeePersonality: Image { Image("pages_templatedetail_art_props_coffee_personality") }
        /// `pages/merchant/images/npc-intro/convenience_store.png`
        static var convenienceStore: Image { Image("pages_merchant_images_npc_intro_convenience_store") }
        /// `images/cards/coupon.svg`
        static var coupon: Image { Image("images_cards_coupon") }
        /// `pages/merchant/images/tags/croissant.svg`
        static var croissant: Image { Image("pages_merchant_images_tags_croissant") }
        /// `pages/templatedetail/art/cat/culture.png`
        static var culture: Image { Image("pages_templatedetail_art_cat_culture") }
        /// `pages/merchant/images/tags/cup-soda.svg`
        static var cupSoda: Image { Image("pages_merchant_images_tags_cup_soda") }
        /// `pages/address/images/d_close.png`
        static var dClose: Image { Image("pages_address_images_d_close") }
        /// `subpackageMember/images/d_cyinfo1.png`
        static var dCyinfo1: Image { Image("subpackagemember_images_d_cyinfo1") }
        /// `subpackageMember/images/d_cyinfo2.png`
        static var dCyinfo2: Image { Image("subpackagemember_images_d_cyinfo2") }
        /// `subpackageMember/images/d_cyinfo4.png`
        static var dCyinfo4: Image { Image("subpackagemember_images_d_cyinfo4") }
        /// `pages/publish/images/d_mbico1.png`
        static var dMbico1: Image { Image("pages_publish_images_d_mbico1") }
        /// `pages/publish/images/d_mbico2.png`
        static var dMbico2: Image { Image("pages_publish_images_d_mbico2") }
        /// `subpackageMember/images/d_orderIcon.png`
        static var dOrderIcon: Image { Image("subpackagemember_images_d_ordericon") }
        /// `subpackageMember/images/d_orderIcon2.png`
        static var dOrderIcon2: Image { Image("subpackagemember_images_d_ordericon2") }
        /// `pages/gerenziliao/images/d_sctb.png`
        static var dSctb: Image { Image("pages_gerenziliao_images_d_sctb") }
        /// `pages/topic/images/d_weihao.png`
        static var dWeihao: Image { Image("pages_topic_images_d_weihao") }
        /// `subpackageP3/images/cat/daily.png`
        static var daily: Image { Image("subpackagep3_images_cat_daily") }
        /// `pages/templatedetail/art/props/daily-city-sign.png`
        static var dailyCitySign: Image { Image("pages_templatedetail_art_props_daily_city_sign") }
        /// `pages/templatedetail/art/props/detail-observation.png`
        static var detailObservation: Image { Image("pages_templatedetail_art_props_detail_observation") }
        /// `pages/club/images/tags/dices.svg`
        static var dices: Image { Image("pages_club_images_tags_dices") }
        /// `pages/templatedetail/art/props/diy-drink.png`
        static var diyDrink: Image { Image("pages_templatedetail_art_props_diy_drink") }
        /// `pages/club/images/tags/drama.svg`
        static var drama: Image { Image("pages_club_images_tags_drama") }
        /// `subpackageP3/images/cat/electronics.png`
        static var electronics: Image { Image("subpackagep3_images_cat_electronics") }
        /// `images/publish-quick/explore.png`
        static var explore: Image { Image("images_publish_quick_explore") }
        /// `pages/templatedetail/art/cat/family.png`
        static var family: Image { Image("pages_templatedetail_art_cat_family") }
        /// `pages/templatedetail/art/3d/flashlight.png`
        static var flashlight: Image { Image("pages_templatedetail_art_3d_flashlight") }
        /// `pages/templatedetail/art/props/flavor-stamp.png`
        static var flavorStamp: Image { Image("pages_templatedetail_art_props_flavor_stamp") }
        /// `pages/merchant/images/tags/flower-2.svg`
        static var flower2: Image { Image("pages_merchant_images_tags_flower_2") }
        /// `pages/templatedetail/art/cat/food.png`
        static var food: Image { Image("pages_templatedetail_art_cat_food") }
        /// `pages/club/images/tags/footprints.svg`
        static var footprints: Image { Image("pages_club_images_tags_footprints") }
        /// `pages/merchant/images/npc-intro/fork_and_knife_with_plate.png`
        static var forkAndKnifeWithPlate: Image { Image("pages_merchant_images_npc_intro_fork_and_knife_with_plate") }
        /// `pages/merchant/images/tags/frame.svg`
        static var frame: Image { Image("pages_merchant_images_tags_frame") }
        /// `pages/templatedetail/art/cat/fun.png`
        static var fun: Image { Image("pages_templatedetail_art_cat_fun") }
        /// `pages/club/images/tags/game-handle.svg`
        static var gameHandle: Image { Image("pages_club_images_tags_game_handle") }
        /// `pages/templatedetail/art/props/gather.png`
        static var gather: Image { Image("pages_templatedetail_art_props_gather") }
        /// `images/cards/gift.svg`
        static var gift: Image { Image("images_cards_gift") }
        /// `subpackageRoam/assets/icons/goals.png`
        static var goals: Image { Image("subpackageroam_assets_icons_goals") }
        /// `pages/merchant/images/tags/heart-pulse.svg`
        static var heartPulse: Image { Image("pages_merchant_images_tags_heart_pulse") }
        /// `subpackageRoam/assets/icons/history.png`
        static var history: Image { Image("subpackageroam_assets_icons_history") }
        /// `pages/shezhi/images/icon_agreement.svg`
        static var iconAgreement: Image { Image("pages_shezhi_images_icon_agreement") }
        /// `images/icon_bell.svg`
        static var iconBell: Image { Image("images_icon_bell") }
        /// `pages/topic/images/icon_bm.svg`
        static var iconBm: Image { Image("pages_topic_images_icon_bm") }
        /// `pages/topic/images/icon_bm_on.svg`
        static var iconBmOn: Image { Image("pages_topic_images_icon_bm_on") }
        /// `pages/merchant/images/merchant/reviews/icon-bubble.svg`
        static var iconBubble: Image { Image("pages_merchant_images_merchant_reviews_icon_bubble") }
        /// `pages/merchant/images/icon_calendar.svg`
        static var iconCalendar: Image { Image("pages_merchant_images_icon_calendar") }
        /// `images/icon_cat.png`
        static var iconCat: Image { Image("images_icon_cat") }
        /// `images/icon_cat2.png`
        static var iconCat2: Image { Image("images_icon_cat2") }
        /// `pages/merchant/images/merchant/reviews/icon-check-blue.svg`
        static var iconCheckBlue: Image { Image("pages_merchant_images_merchant_reviews_icon_check_blue") }
        /// `pages/merchant/images/merchant/reviews/icon-check-green.svg`
        static var iconCheckGreen: Image { Image("pages_merchant_images_merchant_reviews_icon_check_green") }
        /// `subpackageP3/images/icon_close_sm.png`
        static var iconCloseSm: Image { Image("subpackagep3_images_icon_close_sm") }
        /// `pages/merchant/images/icon_copy.svg`
        static var iconCopy: Image { Image("pages_merchant_images_icon_copy") }
        /// `pages/topic/images/icon_creator_spark.svg`
        static var iconCreatorSpark: Image { Image("pages_topic_images_icon_creator_spark") }
        /// `pages/publish/images/icon_date3.png`
        static var iconDate3: Image { Image("pages_publish_images_icon_date3") }
        /// `pages/shezhi/images/icon_flag_blue.svg`
        static var iconFlagBlue: Image { Image("pages_shezhi_images_icon_flag_blue") }
        /// `subpackageMember/signup/icon_go.svg`
        static var iconGo: Image { Image("subpackagemember_signup_icon_go") }
        /// `pages/shezhi/images/icon_headset.svg`
        static var iconHeadset: Image { Image("pages_shezhi_images_icon_headset") }
        /// `pages/shezhi/images/icon_heart.svg`
        static var iconHeart: Image { Image("pages_shezhi_images_icon_heart") }
        /// `pages/square/images/icon_jia.png`
        static var iconJia: Image { Image("pages_square_images_icon_jia") }
        /// `pages/shezhi/images/icon_lc_compass.svg`
        static var iconLcCompass: Image { Image("pages_shezhi_images_icon_lc_compass") }
        /// `pages/shezhi/images/icon_lc_gift.svg`
        static var iconLcGift: Image { Image("pages_shezhi_images_icon_lc_gift") }
        /// `pages/shezhi/images/icon_lc_info.svg`
        static var iconLcInfo: Image { Image("pages_shezhi_images_icon_lc_info") }
        /// `pages/shezhi/images/icon_lc_lock-keyhole.svg`
        static var iconLcLockKeyhole: Image { Image("pages_shezhi_images_icon_lc_lock_keyhole") }
        /// `pages/shezhi/images/icon_lc_megaphone.svg`
        static var iconLcMegaphone: Image { Image("pages_shezhi_images_icon_lc_megaphone") }
        /// `pages/shezhi/images/icon_lc_message-square-text.svg`
        static var iconLcMessageSquareText: Image { Image("pages_shezhi_images_icon_lc_message_square_text") }
        /// `pages/shezhi/images/icon_lc_scroll-text.svg`
        static var iconLcScrollText: Image { Image("pages_shezhi_images_icon_lc_scroll_text") }
        /// `pages/shezhi/images/icon_lc_shield-alert.svg`
        static var iconLcShieldAlert: Image { Image("pages_shezhi_images_icon_lc_shield_alert") }
        /// `pages/shezhi/images/icon_lc_store.svg`
        static var iconLcStore: Image { Image("pages_shezhi_images_icon_lc_store") }
        /// `pages/shezhi/images/icon_lc_ticket.svg`
        static var iconLcTicket: Image { Image("pages_shezhi_images_icon_lc_ticket") }
        /// `pages/shezhi/images/icon_lc_user-round-x.svg`
        static var iconLcUserRoundX: Image { Image("pages_shezhi_images_icon_lc_user_round_x") }
        /// `pages/shezhi/images/icon_logout.svg`
        static var iconLogout: Image { Image("pages_shezhi_images_icon_logout") }
        /// `images/index-figma/icon-member.png`
        static var iconMember: Image { Image("images_index_figma_icon_member") }
        /// `subpackageMember/images/icon_pen.svg`
        static var iconPen: Image { Image("subpackagemember_images_icon_pen") }
        /// `pages/topic/images/icon_photo2.png`
        static var iconPhoto2: Image { Image("pages_topic_images_icon_photo2") }
        /// `subpackageMember/signup/icon_play.svg`
        static var iconPlay: Image { Image("subpackagemember_signup_icon_play") }
        /// `pages/merchant/images/merchant/reviews/icon-plus.svg`
        static var iconPlus: Image { Image("pages_merchant_images_merchant_reviews_icon_plus") }
        /// `pages/shezhi/images/icon_privacy.svg`
        static var iconPrivacy: Image { Image("pages_shezhi_images_icon_privacy") }
        /// `pages/topic/images/icon_qa_club.svg`
        static var iconQaClub: Image { Image("pages_topic_images_icon_qa_club") }
        /// `pages/topic/images/icon_qa_edit.svg`
        static var iconQaEdit: Image { Image("pages_topic_images_icon_qa_edit") }
        /// `pages/shezhi/images/icon_qa_person.svg`
        static var iconQaPerson: Image { Image("pages_shezhi_images_icon_qa_person") }
        /// `pages/topic/images/icon_qa_scan.svg`
        static var iconQaScan: Image { Image("pages_topic_images_icon_qa_scan") }
        /// `pages/topic/images/icon_qa_store.svg`
        static var iconQaStore: Image { Image("pages_topic_images_icon_qa_store") }
        /// `images/icon_right.png`
        static var iconRight: Image { Image("images_icon_right") }
        /// `images/icon_rz.png`
        static var iconRz: Image { Image("images_icon_rz") }
        /// `pages/templatedetail/images/icon_search.svg`
        static var iconSearch: Image { Image("pages_templatedetail_images_icon_search") }
        /// `pages/merchant/images/merchant/reviews/icon-send.svg`
        static var iconSend: Image { Image("pages_merchant_images_merchant_reviews_icon_send") }
        /// `subpackageMember/images/icon_set.png`
        static var iconSet: Image { Image("subpackagemember_images_icon_set") }
        /// `images/icon_share.png`
        static var iconShare: Image { Image("images_icon_share") }
        /// `images/icon_shop.svg`
        static var iconShop: Image { Image("images_icon_shop") }
        /// `images/index-figma/icon-star.png`
        static var iconStar: Image { Image("images_index_figma_icon_star") }
        /// `pages/topic/images/icon_star1.png`
        static var iconStar1: Image { Image("pages_topic_images_icon_star1") }
        /// `pages/topic/images/icon_star2.png`
        static var iconStar2: Image { Image("pages_topic_images_icon_star2") }
        /// `pages/merchant/images/merchant/reviews/icon-star-filled.svg`
        static var iconStarFilled: Image { Image("pages_merchant_images_merchant_reviews_icon_star_filled") }
        /// `pages/merchant/images/merchant/reviews/icon-star-muted.svg`
        static var iconStarMuted: Image { Image("pages_merchant_images_merchant_reviews_icon_star_muted") }
        /// `pages/merchant/images/merchant/reviews/icon-star-outline.svg`
        static var iconStarOutline: Image { Image("pages_merchant_images_merchant_reviews_icon_star_outline") }
        /// `pages/merchant/images/merchant/reviews/icon-star-small.svg`
        static var iconStarSmall: Image { Image("pages_merchant_images_merchant_reviews_icon_star_small") }
        /// `pages/publish/images/icon_tag_check.svg`
        static var iconTagCheck: Image { Image("pages_publish_images_icon_tag_check") }
        /// `pages/topic/images/icon_todo_check.svg`
        static var iconTodoCheck: Image { Image("pages_topic_images_icon_todo_check") }
        /// `pages/mylike/images/icon_up.png`
        static var iconUp: Image { Image("pages_mylike_images_icon_up") }
        /// `images/index-figma/icon-viewers.png`
        static var iconViewers: Image { Image("images_index_figma_icon_viewers") }
        /// `images/publish-quick/interaction.png`
        static var interaction: Image { Image("images_publish_quick_interaction") }
        /// `images/roam/intro-ticket-map.svg`
        static var introTicketMap: Image { Image("images_roam_intro_ticket_map") }
        /// `images/roam/intro-ticket-route.svg`
        static var introTicketRoute: Image { Image("images_roam_intro_ticket_route") }
        /// `images/roam/intro-ticket-team.svg`
        static var introTicketTeam: Image { Image("images_roam_intro_ticket_team") }
        /// `pages/merchant/images/tags/landmark.svg`
        static var landmark: Image { Image("pages_merchant_images_tags_landmark") }
        /// `pages/templatedetail/art/props/low-carbon.png`
        static var lowCarbon: Image { Image("pages_templatedetail_art_props_low_carbon") }
        /// `pages/templatedetail/art/3d/magnifier.png`
        static var magnifier: Image { Image("pages_templatedetail_art_3d_magnifier") }
        /// `images/cards/members.svg`
        static var members: Image { Image("images_cards_members") }
        /// `pages/templatedetail/art/props/midnight-radio.png`
        static var midnightRadio: Image { Image("pages_templatedetail_art_props_midnight_radio") }
        /// `pages/merchant/images/tags/moon.svg`
        static var moon: Image { Image("pages_merchant_images_tags_moon") }
        /// `pages/club/images/tags/music.svg`
        static var music: Image { Image("pages_club_images_tags_music") }
        /// `pages/templatedetail/art/props/music-corner.png`
        static var musicCorner: Image { Image("pages_templatedetail_art_props_music_corner") }
        /// `pages/merchant/images/npc-intro/name_badge.png`
        static var nameBadge: Image { Image("pages_merchant_images_npc_intro_name_badge") }
        /// `pages/club/images/tags/noodles.svg`
        static var noodles: Image { Image("pages_club_images_tags_noodles") }
        /// `subpackageP3/images/album-intro/object.png`
        static var object: Image { Image("subpackagep3_images_album_intro_object") }
        /// `subpackageMember/images/album/object-3d.png`
        static var object3d: Image { Image("subpackagemember_images_album_object_3d") }
        /// `pages/templatedetail/art/cat/other.png`
        static var other: Image { Image("pages_templatedetail_art_cat_other") }
        /// `pages/merchant/images/tags/outdoor.svg`
        static var outdoor: Image { Image("pages_merchant_images_tags_outdoor") }
        /// `pages/merchant/images/tags/coffee.svg`
        static var pagesMerchantImagesTagsCoffee: Image { Image("pages_merchant_images_tags_coffee") }
        /// `pages/merchant/images/tags/dices.svg`
        static var pagesMerchantImagesTagsDices: Image { Image("pages_merchant_images_tags_dices") }
        /// `pages/merchant/images/tags/drama.svg`
        static var pagesMerchantImagesTagsDrama: Image { Image("pages_merchant_images_tags_drama") }
        /// `pages/merchant/images/tags/footprints.svg`
        static var pagesMerchantImagesTagsFootprints: Image { Image("pages_merchant_images_tags_footprints") }
        /// `pages/merchant/images/tags/game-handle.svg`
        static var pagesMerchantImagesTagsGameHandle: Image { Image("pages_merchant_images_tags_game_handle") }
        /// `pages/merchant/images/tags/music.svg`
        static var pagesMerchantImagesTagsMusic: Image { Image("pages_merchant_images_tags_music") }
        /// `pages/merchant/images/tags/noodles.svg`
        static var pagesMerchantImagesTagsNoodles: Image { Image("pages_merchant_images_tags_noodles") }
        /// `pages/merchant/images/tags/platte.svg`
        static var pagesMerchantImagesTagsPlatte: Image { Image("pages_merchant_images_tags_platte") }
        /// `pages/merchant/images/tags/sport.svg`
        static var pagesMerchantImagesTagsSport: Image { Image("pages_merchant_images_tags_sport") }
        /// `pages/merchant/images/tags/voice.svg`
        static var pagesMerchantImagesTagsVoice: Image { Image("pages_merchant_images_tags_voice") }
        /// `pages/templatedetail/art/cat/city.png`
        static var pagesTemplatedetailArtCatCity: Image { Image("pages_templatedetail_art_cat_city") }
        /// `pages/templatedetail/art/cat/coffee.png`
        static var pagesTemplatedetailArtCatCoffee: Image { Image("pages_templatedetail_art_cat_coffee") }
        /// `pages/templatedetail/art/cat/sport.png`
        static var pagesTemplatedetailArtCatSport: Image { Image("pages_templatedetail_art_cat_sport") }
        /// `pages/templatedetail/art/tab/check.svg`
        static var pagesTemplatedetailArtTabCheck: Image { Image("pages_templatedetail_art_tab_check") }
        /// `pages/templatedetail/art/tab/clock.svg`
        static var pagesTemplatedetailArtTabClock: Image { Image("pages_templatedetail_art_tab_clock") }
        /// `pages/topic/images/icon_copy.svg`
        static var pagesTopicImagesIconCopy: Image { Image("pages_topic_images_icon_copy") }
        /// `pages/topic/images/icon_qa_person.svg`
        static var pagesTopicImagesIconQaPerson: Image { Image("pages_topic_images_icon_qa_person") }
        /// `pages/merchant/images/tags/parachute.svg`
        static var parachute: Image { Image("pages_merchant_images_tags_parachute") }
        /// `pages/merchant/images/tags/paw-print.svg`
        static var pawPrint: Image { Image("pages_merchant_images_tags_paw_print") }
        /// `pages/merchant/images/npc-intro/performing_arts.png`
        static var performingArts: Image { Image("pages_merchant_images_npc_intro_performing_arts") }
        /// `pages/templatedetail/art/cat/pet.png`
        static var pet: Image { Image("pages_templatedetail_art_cat_pet") }
        /// `pages/templatedetail/art/cat/photo.png`
        static var photo: Image { Image("pages_templatedetail_art_cat_photo") }
        /// `pages/templatedetail/art/props/photo-moment.png`
        static var photoMoment: Image { Image("pages_templatedetail_art_props_photo_moment") }
        /// `images/cards/pin.svg`
        static var pin: Image { Image("images_cards_pin") }
        /// `pages/club/images/tags/platte.svg`
        static var platte: Image { Image("pages_club_images_tags_platte") }
        /// `pages/templatedetail/art/props/relay.png`
        static var relay: Image { Image("pages_templatedetail_art_props_relay") }
        /// `pages/templatedetail/art/cat/repair.png`
        static var repair: Image { Image("pages_templatedetail_art_cat_repair") }
        /// `pages/merchant/images/tags/ripple.svg`
        static var ripple: Image { Image("pages_merchant_images_tags_ripple") }
        /// `pages/templatedetail/art/props/role-mission.png`
        static var roleMission: Image { Image("pages_templatedetail_art_props_role_mission") }
        /// `pages/merchant/images/tags/scissors.svg`
        static var scissors: Image { Image("pages_merchant_images_tags_scissors") }
        /// `pages/templatedetail/art/props/secret-code.png`
        static var secretCode: Image { Image("pages_templatedetail_art_props_secret_code") }
        /// `pages/templatedetail/art/props/secret-question.png`
        static var secretQuestion: Image { Image("pages_templatedetail_art_props_secret_question") }
        /// `pages/templatedetail/art/props/signature-dish.png`
        static var signatureDish: Image { Image("pages_templatedetail_art_props_signature_dish") }
        /// `pages/templatedetail/art/props/silent-order.png`
        static var silentOrder: Image { Image("pages_templatedetail_art_props_silent_order") }
        /// `pages/merchant/images/npc-intro/sparkles.png`
        static var sparkles: Image { Image("pages_merchant_images_npc_intro_sparkles") }
        /// `pages/merchant/images/npc-intro/speech_balloon.png`
        static var speechBalloon: Image { Image("pages_merchant_images_npc_intro_speech_balloon") }
        /// `pages/club/images/tags/sport.svg`
        static var sport: Image { Image("pages_club_images_tags_sport") }
        /// `pages/templatedetail/art/cat/stage.png`
        static var stage: Image { Image("pages_templatedetail_art_cat_stage") }
        /// `subpackageRoam/assets/icons/stamp.png`
        static var stamp: Image { Image("subpackageroam_assets_icons_stamp") }
        /// `pages/templatedetail/art/3d/star.png`
        static var star: Image { Image("pages_templatedetail_art_3d_star") }
        /// `pages/templatedetail/art/props/street-puzzle.png`
        static var streetPuzzle: Image { Image("pages_templatedetail_art_props_street_puzzle") }
        /// `pages/templatedetail/art/props/style-mission.png`
        static var styleMission: Image { Image("pages_templatedetail_art_props_style_mission") }
        /// `subpackageMember/images/d_close.png`
        static var subpackageMemberImagesDClose: Image { Image("subpackagemember_images_d_close") }
        /// `subpackageMember/images/icon_qa_person.svg`
        static var subpackageMemberImagesIconQaPerson: Image { Image("subpackagemember_images_icon_qa_person") }
        /// `subpackageMember/images/icon_star.png`
        static var subpackageMemberImagesIconStar: Image { Image("subpackagemember_images_icon_star") }
        /// `subpackageMember/images/tags/baby.svg`
        static var subpackageMemberImagesTagsBaby: Image { Image("subpackagemember_images_tags_baby") }
        /// `subpackageMember/images/tags/bike.svg`
        static var subpackageMemberImagesTagsBike: Image { Image("subpackagemember_images_tags_bike") }
        /// `subpackageMember/images/tags/book-open.svg`
        static var subpackageMemberImagesTagsBookOpen: Image { Image("subpackagemember_images_tags_book_open") }
        /// `subpackageMember/images/tags/brush.svg`
        static var subpackageMemberImagesTagsBrush: Image { Image("subpackagemember_images_tags_brush") }
        /// `subpackageMember/images/tags/camera.svg`
        static var subpackageMemberImagesTagsCamera: Image { Image("subpackagemember_images_tags_camera") }
        /// `subpackageMember/images/tags/coffee.svg`
        static var subpackageMemberImagesTagsCoffee: Image { Image("subpackagemember_images_tags_coffee") }
        /// `subpackageMember/images/tags/croissant.svg`
        static var subpackageMemberImagesTagsCroissant: Image { Image("subpackagemember_images_tags_croissant") }
        /// `subpackageMember/images/tags/cup-soda.svg`
        static var subpackageMemberImagesTagsCupSoda: Image { Image("subpackagemember_images_tags_cup_soda") }
        /// `subpackageMember/images/tags/dices.svg`
        static var subpackageMemberImagesTagsDices: Image { Image("subpackagemember_images_tags_dices") }
        /// `subpackageMember/images/tags/drama.svg`
        static var subpackageMemberImagesTagsDrama: Image { Image("subpackagemember_images_tags_drama") }
        /// `subpackageMember/images/tags/flower-2.svg`
        static var subpackageMemberImagesTagsFlower2: Image { Image("subpackagemember_images_tags_flower_2") }
        /// `subpackageMember/images/tags/footprints.svg`
        static var subpackageMemberImagesTagsFootprints: Image { Image("subpackagemember_images_tags_footprints") }
        /// `subpackageMember/images/tags/frame.svg`
        static var subpackageMemberImagesTagsFrame: Image { Image("subpackagemember_images_tags_frame") }
        /// `subpackageMember/images/tags/game-handle.svg`
        static var subpackageMemberImagesTagsGameHandle: Image { Image("subpackagemember_images_tags_game_handle") }
        /// `subpackageMember/images/tags/heart-pulse.svg`
        static var subpackageMemberImagesTagsHeartPulse: Image { Image("subpackagemember_images_tags_heart_pulse") }
        /// `subpackageMember/images/tags/landmark.svg`
        static var subpackageMemberImagesTagsLandmark: Image { Image("subpackagemember_images_tags_landmark") }
        /// `subpackageMember/images/tags/moon.svg`
        static var subpackageMemberImagesTagsMoon: Image { Image("subpackagemember_images_tags_moon") }
        /// `subpackageMember/images/tags/music.svg`
        static var subpackageMemberImagesTagsMusic: Image { Image("subpackagemember_images_tags_music") }
        /// `subpackageMember/images/tags/noodles.svg`
        static var subpackageMemberImagesTagsNoodles: Image { Image("subpackagemember_images_tags_noodles") }
        /// `subpackageMember/images/tags/outdoor.svg`
        static var subpackageMemberImagesTagsOutdoor: Image { Image("subpackagemember_images_tags_outdoor") }
        /// `subpackageMember/images/tags/parachute.svg`
        static var subpackageMemberImagesTagsParachute: Image { Image("subpackagemember_images_tags_parachute") }
        /// `subpackageMember/images/tags/paw-print.svg`
        static var subpackageMemberImagesTagsPawPrint: Image { Image("subpackagemember_images_tags_paw_print") }
        /// `subpackageMember/images/tags/platte.svg`
        static var subpackageMemberImagesTagsPlatte: Image { Image("subpackagemember_images_tags_platte") }
        /// `subpackageMember/images/tags/ripple.svg`
        static var subpackageMemberImagesTagsRipple: Image { Image("subpackagemember_images_tags_ripple") }
        /// `subpackageMember/images/tags/scissors.svg`
        static var subpackageMemberImagesTagsScissors: Image { Image("subpackagemember_images_tags_scissors") }
        /// `subpackageMember/images/tags/sport.svg`
        static var subpackageMemberImagesTagsSport: Image { Image("subpackagemember_images_tags_sport") }
        /// `subpackageMember/images/tags/tennis.svg`
        static var subpackageMemberImagesTagsTennis: Image { Image("subpackagemember_images_tags_tennis") }
        /// `subpackageMember/images/tags/tent.svg`
        static var subpackageMemberImagesTagsTent: Image { Image("subpackagemember_images_tags_tent") }
        /// `subpackageMember/images/tags/viencharts.svg`
        static var subpackageMemberImagesTagsViencharts: Image { Image("subpackagemember_images_tags_viencharts") }
        /// `subpackageMember/images/tags/voice.svg`
        static var subpackageMemberImagesTagsVoice: Image { Image("subpackagemember_images_tags_voice") }
        /// `subpackageMember/images/tags/weixin-market.svg`
        static var subpackageMemberImagesTagsWeixinMarket: Image { Image("subpackagemember_images_tags_weixin_market") }
        /// `subpackageMember/images/tags/wine.svg`
        static var subpackageMemberImagesTagsWine: Image { Image("subpackagemember_images_tags_wine") }
        /// `subpackageP3/images/cat/food.png`
        static var subpackageP3ImagesCatFood: Image { Image("subpackagep3_images_cat_food") }
        /// `subpackageP3/images/cat/other.png`
        static var subpackageP3ImagesCatOther: Image { Image("subpackagep3_images_cat_other") }
        /// `pages/templatedetail/art/props/table-bingo.png`
        static var tableBingo: Image { Image("pages_templatedetail_art_props_table_bingo") }
        /// `pages/templatedetail/art/props/tag-ball.png`
        static var tagBall: Image { Image("pages_templatedetail_art_props_tag_ball") }
        /// `pages/templatedetail/art/props/tag-balloon.png`
        static var tagBalloon: Image { Image("pages_templatedetail_art_props_tag_balloon") }
        /// `pages/templatedetail/art/props/tag-bar.png`
        static var tagBar: Image { Image("pages_templatedetail_art_props_tag_bar") }
        /// `pages/templatedetail/art/props/tag-blind.png`
        static var tagBlind: Image { Image("pages_templatedetail_art_props_tag_blind") }
        /// `pages/templatedetail/art/props/tag-books.png`
        static var tagBooks: Image { Image("pages_templatedetail_art_props_tag_books") }
        /// `pages/templatedetail/art/props/tag-cafe.png`
        static var tagCafe: Image { Image("pages_templatedetail_art_props_tag_cafe") }
        /// `pages/templatedetail/art/props/tag-clock1.png`
        static var tagClock1: Image { Image("pages_templatedetail_art_props_tag_clock1") }
        /// `pages/templatedetail/art/props/tag-clocktower.png`
        static var tagClocktower: Image { Image("pages_templatedetail_art_props_tag_clocktower") }
        /// `pages/templatedetail/art/props/tag-collect.png`
        static var tagCollect: Image { Image("pages_templatedetail_art_props_tag_collect") }
        /// `pages/templatedetail/art/props/tag-daily.png`
        static var tagDaily: Image { Image("pages_templatedetail_art_props_tag_daily") }
        /// `pages/templatedetail/art/props/tag-dining.png`
        static var tagDining: Image { Image("pages_templatedetail_art_props_tag_dining") }
        /// `pages/templatedetail/art/props/tag-fashion.png`
        static var tagFashion: Image { Image("pages_templatedetail_art_props_tag_fashion") }
        /// `pages/templatedetail/art/props/tag-firstaid.png`
        static var tagFirstaid: Image { Image("pages_templatedetail_art_props_tag_firstaid") }
        /// `pages/templatedetail/art/props/tag-icebreak.png`
        static var tagIcebreak: Image { Image("pages_templatedetail_art_props_tag_icebreak") }
        /// `pages/templatedetail/art/props/tag-lamp.png`
        static var tagLamp: Image { Image("pages_templatedetail_art_props_tag_lamp") }
        /// `pages/templatedetail/art/props/tag-local.png`
        static var tagLocal: Image { Image("pages_templatedetail_art_props_tag_local") }
        /// `pages/templatedetail/art/props/tag-map.png`
        static var tagMap: Image { Image("pages_templatedetail_art_props_tag_map") }
        /// `pages/templatedetail/art/props/tag-music.png`
        static var tagMusic: Image { Image("pages_templatedetail_art_props_tag_music") }
        /// `pages/templatedetail/art/props/tag-night.png`
        static var tagNight: Image { Image("pages_templatedetail_art_props_tag_night") }
        /// `pages/templatedetail/art/props/tag-p3.png`
        static var tagP3: Image { Image("pages_templatedetail_art_props_tag_p3") }
        /// `pages/templatedetail/art/props/tag-photo.png`
        static var tagPhoto: Image { Image("pages_templatedetail_art_props_tag_photo") }
        /// `pages/templatedetail/art/props/tag-pin.png`
        static var tagPin: Image { Image("pages_templatedetail_art_props_tag_pin") }
        /// `pages/templatedetail/art/props/tag-promo.png`
        static var tagPromo: Image { Image("pages_templatedetail_art_props_tag_promo") }
        /// `pages/templatedetail/art/props/tag-puzzle.png`
        static var tagPuzzle: Image { Image("pages_templatedetail_art_props_tag_puzzle") }
        /// `pages/templatedetail/art/props/tag-quick.png`
        static var tagQuick: Image { Image("pages_templatedetail_art_props_tag_quick") }
        /// `pages/templatedetail/art/props/tag-quiz.png`
        static var tagQuiz: Image { Image("pages_templatedetail_art_props_tag_quiz") }
        /// `pages/templatedetail/art/props/tag-rack.png`
        static var tagRack: Image { Image("pages_templatedetail_art_props_tag_rack") }
        /// `pages/templatedetail/art/props/tag-relay.png`
        static var tagRelay: Image { Image("pages_templatedetail_art_props_tag_relay") }
        /// `pages/templatedetail/art/props/tag-roleplay.png`
        static var tagRoleplay: Image { Image("pages_templatedetail_art_props_tag_roleplay") }
        /// `pages/templatedetail/art/props/tag-silent.png`
        static var tagSilent: Image { Image("pages_templatedetail_art_props_tag_silent") }
        /// `pages/templatedetail/art/props/tag-story.png`
        static var tagStory: Image { Image("pages_templatedetail_art_props_tag_story") }
        /// `pages/templatedetail/art/props/tag-suitcase.png`
        static var tagSuitcase: Image { Image("pages_templatedetail_art_props_tag_suitcase") }
        /// `pages/templatedetail/art/props/tag-taste.png`
        static var tagTaste: Image { Image("pages_templatedetail_art_props_tag_taste") }
        /// `pages/templatedetail/art/props/tag-teambuild.png`
        static var tagTeambuild: Image { Image("pages_templatedetail_art_props_tag_teambuild") }
        /// `pages/templatedetail/art/props/tag-tent.png`
        static var tagTent: Image { Image("pages_templatedetail_art_props_tag_tent") }
        /// `pages/templatedetail/art/props/tag-vending.png`
        static var tagVending: Image { Image("pages_templatedetail_art_props_tag_vending") }
        /// `pages/templatedetail/art/props/team-energy.png`
        static var teamEnergy: Image { Image("pages_templatedetail_art_props_team_energy") }
        /// `pages/templatedetail/art/props/team-race.png`
        static var teamRace: Image { Image("pages_templatedetail_art_props_team_race") }
        /// `pages/templatedetail/art/cat/tech.png`
        static var tech: Image { Image("pages_templatedetail_art_cat_tech") }
        /// `pages/merchant/images/tags/tennis.svg`
        static var tennis: Image { Image("pages_merchant_images_tags_tennis") }
        /// `pages/merchant/images/tags/tent.svg`
        static var tent: Image { Image("pages_merchant_images_tags_tent") }
        /// `subpackageP3/images/cat/toys.png`
        static var toys: Image { Image("subpackagep3_images_cat_toys") }
        /// `pages/templatedetail/art/cat/travel.png`
        static var travel: Image { Image("pages_templatedetail_art_cat_travel") }
        /// `pages/merchant/images/tags/viencharts.svg`
        static var viencharts: Image { Image("pages_merchant_images_tags_viencharts") }
        /// `pages/club/images/tags/voice.svg`
        static var voice: Image { Image("pages_club_images_tags_voice") }
        /// `pages/merchant/images/npc-intro/waving_hand.png`
        static var wavingHand: Image { Image("pages_merchant_images_npc_intro_waving_hand") }
        /// `pages/merchant/images/tags/weixin-market.svg`
        static var weixinMarket: Image { Image("pages_merchant_images_tags_weixin_market") }
        /// `pages/merchant/images/tags/wine.svg`
        static var wine: Image { Image("pages_merchant_images_tags_wine") }
        /// `pages/templatedetail/art/cat/world.png`
        static var world: Image { Image("pages_templatedetail_art_cat_world") }
    }

    enum BadgeMedal {
        /// `subpackageP3/assets/badge-demo.png`
        static var badgeDemo: Image { Image("subpackagep3_assets_badge_demo") }
        /// `pages/play/components/medal-screen/gl_book.svg`
        static var glBook: Image { Image("pages_play_components_medal_screen_gl_book") }
        /// `pages/play/components/medal-screen/gl_clock.svg`
        static var glClock: Image { Image("pages_play_components_medal_screen_gl_clock") }
        /// `pages/play/components/medal-screen/gl_shop.svg`
        static var glShop: Image { Image("pages_play_components_medal_screen_gl_shop") }
        /// `pages/play/components/medal-screen/gl_spark.svg`
        static var glSpark: Image { Image("pages_play_components_medal_screen_gl_spark") }
        /// `pages/play/components/medal-screen/gl_stamp.svg`
        static var glStamp: Image { Image("pages_play_components_medal_screen_gl_stamp") }
        /// `pages/play/components/medal-screen/gl_trophy.svg`
        static var glTrophy: Image { Image("pages_play_components_medal_screen_gl_trophy") }
        /// `pages/play/components/medal-screen/gl_walk.svg`
        static var glWalk: Image { Image("pages_play_components_medal_screen_gl_walk") }
        /// `pages/play/images/frames/glass-badge.webp`
        static var glassBadge: Image { Image("pages_play_images_frames_glass_badge") }
        /// `subpackageP3/assets/gold-matcap.png`
        static var goldMatcap: Image { Image("subpackagep3_assets_gold_matcap") }
        /// `subpackageMember/images/group2.png`
        static var group2: Image { Image("subpackagemember_images_group2") }
        /// `subpackageMember/images/group3.png`
        static var group3: Image { Image("subpackagemember_images_group3") }
        /// `subpackageMember/images/group4.png`
        static var group4: Image { Image("subpackagemember_images_group4") }
        /// `subpackageMember/images/group5.png`
        static var group5: Image { Image("subpackagemember_images_group5") }
        /// `subpackageJourney/images/laurel.svg`
        static var laurel: Image { Image("subpackagejourney_images_laurel") }
        /// `subpackageP3/images/album-intro/medal.png`
        static var medal: Image { Image("subpackagep3_images_album_intro_medal") }
        /// `subpackageMember/images/album/medal-3d.png`
        static var medal3d: Image { Image("subpackagemember_images_album_medal_3d") }
        /// `components/cy/completion-share-card/medal-bronze.svg`
        static var medalBronze: Image { Image("components_cy_completion_share_card_medal_bronze") }
        /// `components/cy/completion-share-card/medal-gold.svg`
        static var medalGold: Image { Image("components_cy_completion_share_card_medal_gold") }
        /// `components/cy/completion-share-card/medal-silver.svg`
        static var medalSilver: Image { Image("components_cy_completion_share_card_medal_silver") }
        /// `pages/play/components/medal-screen/mic_chest.svg`
        static var micChest: Image { Image("pages_play_components_medal_screen_mic_chest") }
        /// `pages/play/components/medal-screen/mic_env.svg`
        static var micEnv: Image { Image("pages_play_components_medal_screen_mic_env") }
        /// `pages/play/components/medal-screen/mic_key.svg`
        static var micKey: Image { Image("pages_play_components_medal_screen_mic_key") }
        /// `pages/play/components/medal-screen/mic_leaf.svg`
        static var micLeaf: Image { Image("pages_play_components_medal_screen_mic_leaf") }
        /// `pages/play/components/medal-screen/mic_moon.svg`
        static var micMoon: Image { Image("pages_play_components_medal_screen_mic_moon") }
        /// `pages/play/components/medal-screen/mic_stamp.svg`
        static var micStamp: Image { Image("pages_play_components_medal_screen_mic_stamp") }
        /// `subpackageP3/images/album-intro/stamp.png`
        static var stamp: Image { Image("subpackagep3_images_album_intro_stamp") }
        /// `subpackageMember/images/album/stamp-3d.png`
        static var stamp3d: Image { Image("subpackagemember_images_album_stamp_3d") }
        /// `pages/templatedetail/art/props/tag-trophy.png`
        static var tagTrophy: Image { Image("pages_templatedetail_art_props_tag_trophy") }
        /// `images/play/trophy.png`
        static var trophy: Image { Image("images_play_trophy") }
    }

    enum EmptyState {
        /// `images/empty_state_bg.svg`
        static var emptyStateBg: Image { Image("images_empty_state_bg") }
        /// `images/empty_state_figure.svg`
        static var emptyStateFigure: Image { Image("images_empty_state_figure") }
        /// `subpackageMember/images/icon_ticket_empty.svg`
        static var iconTicketEmpty: Image { Image("subpackagemember_images_icon_ticket_empty") }
        /// `images/no_data.svg`
        static var noData: Image { Image("images_no_data") }
    }

    enum BannerCover {
        /// `pages/templatedetail/art/covers/topic/anomaly-coordinate.jpg`
        static var anomalyCoordinate: Image { Image("pages_templatedetail_art_covers_topic_anomaly_coordinate") }
        /// `pages/templatedetail/art/covers/topic/apocalypse-broadcast.jpg`
        static var apocalypseBroadcast: Image { Image("pages_templatedetail_art_covers_topic_apocalypse_broadcast") }
        /// `images/interaction-templates/blind-taste.svg`
        static var blindTaste: Image { Image("images_interaction_templates_blind_taste") }
        /// `pages/templatedetail/art/covers/game/blind-test.jpg`
        static var blindTest: Image { Image("pages_templatedetail_art_covers_game_blind_test") }
        /// `pages/templatedetail/art/covers/game/branch-story.jpg`
        static var branchStory: Image { Image("pages_templatedetail_art_covers_game_branch_story") }
        /// `pages/templatedetail/art/covers/game/city-camera.jpg`
        static var cityCamera: Image { Image("pages_templatedetail_art_covers_game_city_camera") }
        /// `images/interaction-templates/club-city-camera.svg`
        static var clubCityCamera: Image { Image("images_interaction_templates_club_city_camera") }
        /// `pages/club/images/club_cover_default.png`
        static var clubCoverDefault: Image { Image("pages_club_images_club_cover_default") }
        /// `images/interaction-templates/club-gather.svg`
        static var clubGather: Image { Image("images_interaction_templates_club_gather") }
        /// `images/interaction-templates/club-relay.svg`
        static var clubRelay: Image { Image("images_interaction_templates_club_relay") }
        /// `images/interaction-templates/club-role-mission.svg`
        static var clubRoleMission: Image { Image("images_interaction_templates_club_role_mission") }
        /// `images/interaction-templates/club-street-puzzle.svg`
        static var clubStreetPuzzle: Image { Image("images_interaction_templates_club_street_puzzle") }
        /// `images/interaction-templates/club-team-race.svg`
        static var clubTeamRace: Image { Image("images_interaction_templates_club_team_race") }
        /// `pages/templatedetail/art/covers/game/coffee-personality.jpg`
        static var coffeePersonality: Image { Image("pages_templatedetail_art_covers_game_coffee_personality") }
        /// `images/cover-route.svg`
        static var coverRoute: Image { Image("images_cover_route") }
        /// `pages/club/images/d_frametu.jpg`
        static var dFrametu: Image { Image("pages_club_images_d_frametu") }
        /// `pages/play/images/d_topic1.png`
        static var dTopic1: Image { Image("pages_play_images_d_topic1") }
        /// `pages/play/images/d_topic2.png`
        static var dTopic2: Image { Image("pages_play_images_d_topic2") }
        /// `pages/play/images/d_topic4.png`
        static var dTopic4: Image { Image("pages_play_images_d_topic4") }
        /// `pages/play/images/d_topic5.png`
        static var dTopic5: Image { Image("pages_play_images_d_topic5") }
        /// `images/interaction-templates/daily-city-sign.svg`
        static var dailyCitySign: Image { Image("images_interaction_templates_daily_city_sign") }
        /// `images/cards/default-cover.png`
        static var defaultCover: Image { Image("images_cards_default_cover") }
        /// `pages/templatedetail/art/covers/game/detail-observation.jpg`
        static var detailObservation: Image { Image("pages_templatedetail_art_covers_game_detail_observation") }
        /// `images/interaction-templates/diy-drink.svg`
        static var diyDrink: Image { Image("images_interaction_templates_diy_drink") }
        /// `subpackageRoam/assets/photos/event.webp`
        static var event: Image { Image("subpackageroam_assets_photos_event") }
        /// `pages/templatedetail/art/covers/topic/fe-coffee.jpg`
        static var feCoffee: Image { Image("pages_templatedetail_art_covers_topic_fe_coffee") }
        /// `pages/templatedetail/art/covers/topic/fe-craft.jpg`
        static var feCraft: Image { Image("pages_templatedetail_art_covers_topic_fe_craft") }
        /// `pages/templatedetail/art/covers/topic/fe-date.jpg`
        static var feDate: Image { Image("pages_templatedetail_art_covers_topic_fe_date") }
        /// `pages/templatedetail/art/covers/topic/fe-friends.jpg`
        static var feFriends: Image { Image("pages_templatedetail_art_covers_topic_fe_friends") }
        /// `pages/templatedetail/art/covers/topic/fe-move.jpg`
        static var feMove: Image { Image("pages_templatedetail_art_covers_topic_fe_move") }
        /// `pages/templatedetail/art/covers/topic/fe-night.jpg`
        static var feNight: Image { Image("pages_templatedetail_art_covers_topic_fe_night") }
        /// `pages/templatedetail/art/covers/topic/fe-style.jpg`
        static var feStyle: Image { Image("pages_templatedetail_art_covers_topic_fe_style") }
        /// `pages/templatedetail/art/covers/topic/fe-tea.jpg`
        static var feTea: Image { Image("pages_templatedetail_art_covers_topic_fe_tea") }
        /// `pages/templatedetail/art/covers/game/flavor-stamp.jpg`
        static var flavorStamp: Image { Image("pages_templatedetail_art_covers_game_flavor_stamp") }
        /// `pages/merchant/images/grow/flavor-tour.jpg`
        static var flavorTour: Image { Image("pages_merchant_images_grow_flavor_tour") }
        /// `pages/templatedetail/art/covers/game/gather.jpg`
        static var gather: Image { Image("pages_templatedetail_art_covers_game_gather") }
        /// `pages/templatedetail/art/covers/topic/heat-escape.jpg`
        static var heatEscape: Image { Image("pages_templatedetail_art_covers_topic_heat_escape") }
        /// `images/home-banner-club.jpg`
        static var homeBannerClub: Image { Image("images_home_banner_club") }
        /// `images/home-banner-friends.jpg`
        static var homeBannerFriends: Image { Image("images_home_banner_friends") }
        /// `images/home-banner-merchant.jpg`
        static var homeBannerMerchant: Image { Image("images_home_banner_merchant") }
        /// `images/home-route-city-placeholder.jpg`
        static var homeRouteCityPlaceholder: Image { Image("images_home_route_city_placeholder") }
        /// `pages/templatedetail/art/covers/topic/life-backup.jpg`
        static var lifeBackup: Image { Image("pages_templatedetail_art_covers_topic_life_backup") }
        /// `images/interaction-templates/life-bottom-line.svg`
        static var lifeBottomLine: Image { Image("images_interaction_templates_life_bottom_line") }
        /// `images/interaction-templates/life-first-choice-offline.svg`
        static var lifeFirstChoiceOffline: Image { Image("images_interaction_templates_life_first_choice_offline") }
        /// `images/interaction-templates/life-hours-puzzle.svg`
        static var lifeHoursPuzzle: Image { Image("images_interaction_templates_life_hours_puzzle") }
        /// `images/interaction-templates/life-outage-test.svg`
        static var lifeOutageTest: Image { Image("images_interaction_templates_life_outage_test") }
        /// `images/interaction-templates/life-prep-checklist.svg`
        static var lifePrepChecklist: Image { Image("images_interaction_templates_life_prep_checklist") }
        /// `images/interaction-templates/life-what-first.svg`
        static var lifeWhatFirst: Image { Image("images_interaction_templates_life_what_first") }
        /// `images/interaction-templates/life-worth-now.svg`
        static var lifeWorthNow: Image { Image("images_interaction_templates_life_worth_now") }
        /// `images/interaction-templates/low-carbon.svg`
        static var lowCarbon: Image { Image("images_interaction_templates_low_carbon") }
        /// `pages/club/images/mer1.jpg`
        static var mer1: Image { Image("pages_club_images_mer1") }
        /// `images/interaction-templates/merchant-blind-test.svg`
        static var merchantBlindTest: Image { Image("images_interaction_templates_merchant_blind_test") }
        /// `pages/merchant/images/merchant_coop_banner.jpg`
        static var merchantCoopBanner: Image { Image("pages_merchant_images_merchant_coop_banner") }
        /// `images/interaction-templates/merchant-flavor-stamp.svg`
        static var merchantFlavorStamp: Image { Image("images_interaction_templates_merchant_flavor_stamp") }
        /// `images/interaction-templates/merchant-photo-moment.svg`
        static var merchantPhotoMoment: Image { Image("images_interaction_templates_merchant_photo_moment") }
        /// `images/interaction-templates/merchant-secret-code.svg`
        static var merchantSecretCode: Image { Image("images_interaction_templates_merchant_secret_code") }
        /// `images/interaction-templates/merchant-secret-question.svg`
        static var merchantSecretQuestion: Image { Image("images_interaction_templates_merchant_secret_question") }
        /// `images/interaction-templates/merchant-style-mission.svg`
        static var merchantStyleMission: Image { Image("images_interaction_templates_merchant_style_mission") }
        /// `pages/merchant/images/grow/midlife-day.jpg`
        static var midlifeDay: Image { Image("pages_merchant_images_grow_midlife_day") }
        /// `images/interaction-templates/midnight-radio.svg`
        static var midnightRadio: Image { Image("images_interaction_templates_midnight_radio") }
        /// `images/interaction-templates/music-corner.svg`
        static var musicCorner: Image { Image("images_interaction_templates_music_corner") }
        /// `images/index-figma/nearby-card.jpg`
        static var nearbyCard: Image { Image("images_index_figma_nearby_card") }
        /// `pages/merchant/images/grow/old-movie.jpg`
        static var oldMovie: Image { Image("pages_merchant_images_grow_old_movie") }
        /// `pages/gerenziliao/images/mer1.jpg`
        static var pagesGerenziliaoImagesMer1: Image { Image("pages_gerenziliao_images_mer1") }
        /// `pages/mylike/images/mer1.jpg`
        static var pagesMylikeImagesMer1: Image { Image("pages_mylike_images_mer1") }
        /// `pages/publish/images/mer1.jpg`
        static var pagesPublishImagesMer1: Image { Image("pages_publish_images_mer1") }
        /// `pages/templatedetail/art/covers/game/blind-taste.jpg`
        static var pagesTemplatedetailArtCoversGameBlindTaste: Image { Image("pages_templatedetail_art_covers_game_blind_taste") }
        /// `pages/templatedetail/art/covers/game/daily-city-sign.jpg`
        static var pagesTemplatedetailArtCoversGameDailyCitySign: Image { Image("pages_templatedetail_art_covers_game_daily_city_sign") }
        /// `pages/templatedetail/art/covers/game/diy-drink.jpg`
        static var pagesTemplatedetailArtCoversGameDiyDrink: Image { Image("pages_templatedetail_art_covers_game_diy_drink") }
        /// `pages/templatedetail/art/covers/game/low-carbon.jpg`
        static var pagesTemplatedetailArtCoversGameLowCarbon: Image { Image("pages_templatedetail_art_covers_game_low_carbon") }
        /// `pages/templatedetail/art/covers/game/midnight-radio.jpg`
        static var pagesTemplatedetailArtCoversGameMidnightRadio: Image { Image("pages_templatedetail_art_covers_game_midnight_radio") }
        /// `pages/templatedetail/art/covers/game/music-corner.jpg`
        static var pagesTemplatedetailArtCoversGameMusicCorner: Image { Image("pages_templatedetail_art_covers_game_music_corner") }
        /// `pages/templatedetail/art/covers/game/silent-order.jpg`
        static var pagesTemplatedetailArtCoversGameSilentOrder: Image { Image("pages_templatedetail_art_covers_game_silent_order") }
        /// `pages/templatedetail/art/covers/topic/flavor-tour.jpg`
        static var pagesTemplatedetailArtCoversTopicFlavorTour: Image { Image("pages_templatedetail_art_covers_topic_flavor_tour") }
        /// `pages/templatedetail/art/covers/topic/midlife-day.jpg`
        static var pagesTemplatedetailArtCoversTopicMidlifeDay: Image { Image("pages_templatedetail_art_covers_topic_midlife_day") }
        /// `pages/templatedetail/art/covers/topic/old-movie.jpg`
        static var pagesTemplatedetailArtCoversTopicOldMovie: Image { Image("pages_templatedetail_art_covers_topic_old_movie") }
        /// `pages/templatedetail/art/covers/topic/treasure-hunter.jpg`
        static var pagesTemplatedetailArtCoversTopicTreasureHunter: Image { Image("pages_templatedetail_art_covers_topic_treasure_hunter") }
        /// `pages/templatedetail/art/covers/game/photo-moment.jpg`
        static var photoMoment: Image { Image("pages_templatedetail_art_covers_game_photo_moment") }
        /// `pages/templatedetail/art/covers/topic/prebuilt-life.jpg`
        static var prebuiltLife: Image { Image("pages_templatedetail_art_covers_topic_prebuilt_life") }
        /// `images/index-figma/reco-hero.jpg`
        static var recoHero: Image { Image("images_index_figma_reco_hero") }
        /// `pages/templatedetail/art/covers/game/relay.jpg`
        static var relay: Image { Image("pages_templatedetail_art_covers_game_relay") }
        /// `pages/templatedetail/art/covers/game/role-mission.jpg`
        static var roleMission: Image { Image("pages_templatedetail_art_covers_game_role_mission") }
        /// `subpackageRoam/components/cy/share-card/route-art.png`
        static var routeArt: Image { Image("subpackageroam_components_cy_share_card_route_art") }
        /// `images/route_city_cover.png`
        static var routeCityCover: Image { Image("images_route_city_cover") }
        /// `pages/club/images/route_free_cover.png`
        static var routeFreeCover: Image { Image("pages_club_images_route_free_cover") }
        /// `pages/publish/images/sample-window.svg`
        static var sampleWindow: Image { Image("pages_publish_images_sample_window") }
        /// `pages/templatedetail/art/covers/game/secret-code.jpg`
        static var secretCode: Image { Image("pages_templatedetail_art_covers_game_secret_code") }
        /// `pages/templatedetail/art/covers/game/secret-question.jpg`
        static var secretQuestion: Image { Image("pages_templatedetail_art_covers_game_secret_question") }
        /// `pages/templatedetail/art/covers/game/signature-dish.jpg`
        static var signatureDish: Image { Image("pages_templatedetail_art_covers_game_signature_dish") }
        /// `images/interaction-templates/silent-order.svg`
        static var silentOrder: Image { Image("images_interaction_templates_silent_order") }
        /// `pages/templatedetail/art/covers/game/street-puzzle.jpg`
        static var streetPuzzle: Image { Image("pages_templatedetail_art_covers_game_street_puzzle") }
        /// `pages/templatedetail/art/covers/game/style-mission.jpg`
        static var styleMission: Image { Image("pages_templatedetail_art_covers_game_style_mission") }
        /// `subpackageA/images/route_free_cover.png`
        static var subpackageAImagesRouteFreeCover: Image { Image("subpackagea_images_route_free_cover") }
        /// `subpackageB/images/route_free_cover.png`
        static var subpackageBImagesRouteFreeCover: Image { Image("subpackageb_images_route_free_cover") }
        /// `subpackageMember/images/mer1.jpg`
        static var subpackageMemberImagesMer1: Image { Image("subpackagemember_images_mer1") }
        /// `subpackageMember/images/route_free_cover.png`
        static var subpackageMemberImagesRouteFreeCover: Image { Image("subpackagemember_images_route_free_cover") }
        /// `pages/templatedetail/art/covers/game/table-bingo.jpg`
        static var tableBingo: Image { Image("pages_templatedetail_art_covers_game_table_bingo") }
        /// `pages/templatedetail/art/covers/game/team-energy.jpg`
        static var teamEnergy: Image { Image("pages_templatedetail_art_covers_game_team_energy") }
        /// `pages/templatedetail/art/covers/game/team-race.jpg`
        static var teamRace: Image { Image("pages_templatedetail_art_covers_game_team_race") }
        /// `pages/templatedetail/art/covers/topic/time-pollution.jpg`
        static var timePollution: Image { Image("pages_templatedetail_art_covers_topic_time_pollution") }
        /// `pages/merchant/images/grow/treasure-hunter.jpg`
        static var treasureHunter: Image { Image("pages_merchant_images_grow_treasure_hunter") }
    }

    enum MapMarker {
        /// `pages/searchmap/images/d_location2.png`
        static var dLocation2: Image { Image("pages_searchmap_images_d_location2") }
        /// `images/d_smapicon.png`
        static var dSmapicon: Image { Image("images_d_smapicon") }
        /// `images/roam/pin/dot-cluster.png`
        static var dotCluster: Image { Image("images_roam_pin_dot_cluster") }
        /// `images/roam/pin/dot-landmark.png`
        static var dotLandmark: Image { Image("images_roam_pin_dot_landmark") }
        /// `images/roam/pin/dot-merchant.png`
        static var dotMerchant: Image { Image("images_roam_pin_dot_merchant") }
        /// `images/roam/pin/dot-park.png`
        static var dotPark: Image { Image("images_roam_pin_dot_park") }
        /// `images/roam/pin/dot-shop.png`
        static var dotShop: Image { Image("images_roam_pin_dot_shop") }
        /// `images/roam/pin/dot-street.png`
        static var dotStreet: Image { Image("images_roam_pin_dot_street") }
        /// `images/roam/pin/dot-unknown.png`
        static var dotUnknown: Image { Image("images_roam_pin_dot_unknown") }
        /// `images/icon_map4.png`
        static var iconMap4: Image { Image("images_icon_map4") }
        /// `pages/searchmap/images/icon_map6.png`
        static var iconMap6: Image { Image("pages_searchmap_images_icon_map6") }
        /// `pages/publish/images/map-pin.png`
        static var mapPin: Image { Image("pages_publish_images_map_pin") }
        /// `pages/searchmap/images/d_smapicon.png`
        static var pagesSearchmapImagesDSmapicon: Image { Image("pages_searchmap_images_d_smapicon") }
        /// `images/roam/pin/pin-landmark.png`
        static var pinLandmark: Image { Image("images_roam_pin_pin_landmark") }
        /// `images/roam/pin/pin-merchant.png`
        static var pinMerchant: Image { Image("images_roam_pin_pin_merchant") }
        /// `images/roam/pin/pin-park.png`
        static var pinPark: Image { Image("images_roam_pin_pin_park") }
        /// `images/roam/pin/pin-shop.png`
        static var pinShop: Image { Image("images_roam_pin_pin_shop") }
        /// `images/roam/pin/pin-street.png`
        static var pinStreet: Image { Image("images_roam_pin_pin_street") }
        /// `images/roam/pin/pin-unknown.png`
        static var pinUnknown: Image { Image("images_roam_pin_pin_unknown") }
        /// `images/roam-pushpin.png`
        static var roamPushpin: Image { Image("images_roam_pushpin") }
    }

    enum AvatarDefault {
        /// `images/d_profile.png`
        static var dProfile: Image { Image("images_d_profile") }
        /// `subpackageP3/images/memoji-1.png`
        static var memoji1: Image { Image("subpackagep3_images_memoji_1") }
        /// `subpackageP3/images/memoji-2.png`
        static var memoji2: Image { Image("subpackagep3_images_memoji_2") }
        /// `subpackageP3/images/memoji-3.png`
        static var memoji3: Image { Image("subpackagep3_images_memoji_3") }
    }

    enum Other {
        /// `pages/topic/images/merchant-guide/clock.svg`
        static var clock: Image { Image("pages_topic_images_merchant_guide_clock") }
        /// `pages/gerenziliao/images/del.png`
        static var del: Image { Image("pages_gerenziliao_images_del") }
        /// `subpackageMember/images/figma-invite-qr.png`
        static var figmaInviteQr: Image { Image("subpackagemember_images_figma_invite_qr") }
        /// `subpackageMember/images/frames/glass-key.webp`
        static var glassKey: Image { Image("subpackagemember_images_frames_glass_key") }
        /// `pages/play/images/frames/glass-success.webp`
        static var glassSuccess: Image { Image("pages_play_images_frames_glass_success") }
        /// `subpackagePass/frames/key-idle-0.webp`
        static var keyIdle0: Image { Image("subpackagepass_frames_key_idle_0") }
        /// `subpackagePass/frames/key-idle-1.webp`
        static var keyIdle1: Image { Image("subpackagepass_frames_key_idle_1") }
        /// `subpackagePass/frames/key-idle-10.webp`
        static var keyIdle10: Image { Image("subpackagepass_frames_key_idle_10") }
        /// `subpackagePass/frames/key-idle-11.webp`
        static var keyIdle11: Image { Image("subpackagepass_frames_key_idle_11") }
        /// `subpackagePass/frames/key-idle-2.webp`
        static var keyIdle2: Image { Image("subpackagepass_frames_key_idle_2") }
        /// `subpackagePass/frames/key-idle-3.webp`
        static var keyIdle3: Image { Image("subpackagepass_frames_key_idle_3") }
        /// `subpackagePass/frames/key-idle-4.webp`
        static var keyIdle4: Image { Image("subpackagepass_frames_key_idle_4") }
        /// `subpackagePass/frames/key-idle-5.webp`
        static var keyIdle5: Image { Image("subpackagepass_frames_key_idle_5") }
        /// `subpackagePass/frames/key-idle-6.webp`
        static var keyIdle6: Image { Image("subpackagepass_frames_key_idle_6") }
        /// `subpackagePass/frames/key-idle-7.webp`
        static var keyIdle7: Image { Image("subpackagepass_frames_key_idle_7") }
        /// `subpackagePass/frames/key-idle-8.webp`
        static var keyIdle8: Image { Image("subpackagepass_frames_key_idle_8") }
        /// `subpackagePass/frames/key-idle-9.webp`
        static var keyIdle9: Image { Image("subpackagepass_frames_key_idle_9") }
        /// `subpackagePass/frames/key-intro-0.webp`
        static var keyIntro0: Image { Image("subpackagepass_frames_key_intro_0") }
        /// `subpackagePass/frames/key-intro-1.webp`
        static var keyIntro1: Image { Image("subpackagepass_frames_key_intro_1") }
        /// `subpackagePass/frames/key-intro-10.webp`
        static var keyIntro10: Image { Image("subpackagepass_frames_key_intro_10") }
        /// `subpackagePass/frames/key-intro-11.webp`
        static var keyIntro11: Image { Image("subpackagepass_frames_key_intro_11") }
        /// `subpackagePass/frames/key-intro-12.webp`
        static var keyIntro12: Image { Image("subpackagepass_frames_key_intro_12") }
        /// `subpackagePass/frames/key-intro-13.webp`
        static var keyIntro13: Image { Image("subpackagepass_frames_key_intro_13") }
        /// `subpackagePass/frames/key-intro-2.webp`
        static var keyIntro2: Image { Image("subpackagepass_frames_key_intro_2") }
        /// `subpackagePass/frames/key-intro-3.webp`
        static var keyIntro3: Image { Image("subpackagepass_frames_key_intro_3") }
        /// `subpackagePass/frames/key-intro-4.webp`
        static var keyIntro4: Image { Image("subpackagepass_frames_key_intro_4") }
        /// `subpackagePass/frames/key-intro-5.webp`
        static var keyIntro5: Image { Image("subpackagepass_frames_key_intro_5") }
        /// `subpackagePass/frames/key-intro-6.webp`
        static var keyIntro6: Image { Image("subpackagepass_frames_key_intro_6") }
        /// `subpackagePass/frames/key-intro-7.webp`
        static var keyIntro7: Image { Image("subpackagepass_frames_key_intro_7") }
        /// `subpackagePass/frames/key-intro-8.webp`
        static var keyIntro8: Image { Image("subpackagepass_frames_key_intro_8") }
        /// `subpackagePass/frames/key-intro-9.webp`
        static var keyIntro9: Image { Image("subpackagepass_frames_key_intro_9") }
        /// `pages/topic/images/merchant-guide/location.svg`
        static var location: Image { Image("pages_topic_images_merchant_guide_location") }
        /// `subpackageRoam/citystamp/mailbox.png`
        static var mailbox: Image { Image("subpackageroam_citystamp_mailbox") }
        /// `pages/merchant/images/nav_msg.svg`
        static var navMsg: Image { Image("pages_merchant_images_nav_msg") }
        /// `pages/play/assets/pack-foil.png`
        static var packFoil: Image { Image("pages_play_assets_pack_foil") }
        /// `pages/topic/images/merchant-guide/people.svg`
        static var people: Image { Image("pages_topic_images_merchant_guide_people") }
        /// `subpackageRoam/citystamp/printer-body.jpg`
        static var printerBody: Image { Image("subpackageroam_citystamp_printer_body") }
        /// `subpackageRoam/citystamp/printer-slot.jpg`
        static var printerSlot: Image { Image("subpackageroam_citystamp_printer_slot") }
        /// `pages/playkit/components/playkit-scan/ar/reticle.png`
        static var reticle: Image { Image("pages_playkit_components_playkit_scan_ar_reticle") }
        /// `pages/topic/images/xjt.png`
        static var xjt: Image { Image("pages_topic_images_xjt") }
    }
}
